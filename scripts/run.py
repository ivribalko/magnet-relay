#!/usr/bin/env python3
"""Build quiet Release apps, then install only on the selected named devices."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".derivedData" / "run"
ALL = "All available devices"


def run_logged(command, name):
    """Keep command output on disk and report a bounded failure summary."""
    log = OUTPUT / (name + ".log")
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        lines = log.read_text(errors="replace").splitlines()
        errors = [line for line in lines if "error:" in line.lower()]
        print("\n".join(line[:400] for line in (errors or lines)[-8:]), file=sys.stderr)
        raise RuntimeError(f"{name} failed. Log: {log.relative_to(ROOT)}")
    return log


def device_targets(devices, mac_name):
    """Include this Mac and every available physical iOS device."""
    targets = [{"kind": "mac", "name": mac_name + " (This Mac)", "id": "mac"}]
    seen = set()
    for device in devices:
        platform = device.get("platform")
        if (not device.get("available") or device.get("simulator", False)
                or platform != "com.apple.platform.iphoneos"):
            continue
        identifier = device["identifier"]
        if identifier in seen:
            continue
        seen.add(identifier)
        version = device.get("operatingSystemVersion", "").split(" (")[0]
        suffix = f"iOS {version}"
        targets.append({"kind": "ios", "id": identifier,
                        "name": f'{device["name"]} ({suffix})'})
    return targets[:1] + sorted(targets[1:], key=lambda d: (d["kind"], d["name"], d["id"]))


def discover():
    """Ask Xcode for currently available USB and wireless device targets."""
    log = run_logged(["xcrun", "xcdevice", "list", "--timeout", "10"], "devices")
    devices = json.loads(log.read_text())
    result = subprocess.run(["scutil", "--get", "ComputerName"], capture_output=True, text=True)
    return device_targets(devices, result.stdout.strip() or "This Mac")


def build(kind):
    """Produce separate Release products for each destination platform."""
    platform, destination, product = {
        "mac": ("macOS", "platform=macOS", "Release"),
        "ios": ("iOS", "generic/platform=iOS", "Release-iphoneos"),
    }[kind]
    derived = OUTPUT / kind
    print(f"Building Release: {kind}…", flush=True)
    command = ["xcodebuild", "-quiet", "-project", "Magnet Relay.xcodeproj",
               "-scheme", f"Magnet Relay ({platform})", "-configuration", "Release",
               "-destination", destination, "-derivedDataPath", str(derived),
               "-allowProvisioningUpdates", "build"]
    run_logged(command, "build-" + kind)
    app = derived / "Build" / "Products" / product / "Magnet Relay.app"
    if not app.is_dir():
        raise RuntimeError(f"Missing build product: {app.relative_to(ROOT)}")
    return app


def choose(targets):
    """Show a native multiple-selection picker after the builds have succeeded."""
    labels = [f'{index + 1}. {target["name"]}' for index, target in enumerate(targets)]
    script = '''on run choices
    set picked to choose from list choices with title "Magnet Relay" with prompt "Release builds are ready. Select devices to install on:" OK button name "Install" cancel button name "Cancel" with multiple selections allowed
    if picked is false then return ""
    set AppleScript's text item delimiters to linefeed
    return picked as text
end run'''
    result = subprocess.run(["osascript", "-", ALL, *labels], input=script,
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("Could not show the device picker: " + result.stderr.strip()[:500])
    selected = result.stdout.strip().splitlines()
    if ALL in selected:
        return targets
    return [target for target, label in zip(targets, labels) if label in selected]


def install(target, app):
    """Install on this Mac or a physical iOS device without launching."""
    kind, identifier = target["kind"], target["id"]
    if kind == "mac":
        applications = Path("/Applications")
        applications.mkdir(exist_ok=True)
        destination = applications / app.name
        # Stage the entire bundle so an older installation never retains stale files.
        with tempfile.TemporaryDirectory(prefix=".magnet-relay-", dir=applications) as temp:
            staging = Path(temp) / app.name
            run_logged(["ditto", str(app), str(staging)], "install-mac")
            backup = Path(temp) / "previous.app"
            if destination.exists():
                destination.rename(backup)
            try:
                staging.rename(destination)
            except OSError:
                if backup.exists():
                    backup.rename(destination)
                raise
    elif kind == "ios":
        run_logged(["xcrun", "devicectl", "device", "install", "app", "--quiet",
                    "--timeout", "120", "--device", identifier, str(app)], "install-" + identifier)
    else:
        raise RuntimeError(f"Unsupported installation target: {kind}")


def main(platform="all"):
    kinds = ("mac", "ios") if platform == "all" else (platform,)
    os.umask(0o077)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Prevent overlapping Run clicks from replacing products during installation.
    with (OUTPUT / "run.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("A Run action is already active.")
        products = {kind: build(kind) for kind in kinds}
        # Discover after building so newly connected devices appear in the picker.
        targets = [target for target in discover() if target["kind"] in kinds]
        if not targets:
            print("No available devices for the selected platform.")
            return 0
        print("Release builds ready. Choose installation devices in the dialog.", flush=True)
        selected = choose(targets)
        if not selected:
            print("Installation cancelled.")
            return 0
        failures = 0
        for target in selected:
            print(f'Installing: {target["name"]}…', flush=True)
            try:
                install(target, products[target["kind"]])
                print(f'Installed: {target["name"]}', flush=True)
            except (RuntimeError, OSError) as error:
                failures += 1
                print(str(error), file=sys.stderr)
        print(f"Installed on {len(selected) - failures}/{len(selected)} selected devices.")
        return 1 if failures else 0


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--platform", choices=("all", "mac", "ios"), default="all",
                            help="platform to build and install (default: all)")
        sys.exit(main(parser.parse_args().platform))
    except (RuntimeError, OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("Run cancelled.", file=sys.stderr)
        sys.exit(130)
