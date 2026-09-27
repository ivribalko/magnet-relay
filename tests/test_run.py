"""Checks device selection and install boundaries without building or installing."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("run_action", Path(__file__).parents[1] / "scripts/run.py")
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class RunActionTests(unittest.TestCase):
    """Protects target discovery, explicit selection, and failure handling."""

    def test_discovery_includes_all_supported_available_devices(self):
        def device(identifier, platform, available=True, simulator=False):
            return dict(identifier=identifier, platform="com.apple.platform." + platform,
                        available=available, simulator=simulator, name="Device")
        devices = [device("phone", "iphoneos"), device("tablet", "iphoneos"),
                   device("sim", "iphonesimulator", simulator=True),
                   device("offline", "iphoneos", available=False),
                   device("watch", "watchos"), device("phone", "iphoneos")]
        targets = run.device_targets(devices, "Computer")
        self.assertEqual({t["id"] for t in targets}, {"mac", "phone", "tablet"})
        self.assertEqual(targets[0]["name"], "Computer (This Mac)")

    def test_platform_actions_limit_builds_and_install_choices(self):
        targets = [{"kind": "mac", "name": "Computer"}, {"kind": "ios", "name": "Phone"},
                   {"kind": "ios", "name": "Tablet"}]
        for platform in ("mac", "ios"):
            expected = [target for target in targets if target["kind"] == platform]
            with tempfile.TemporaryDirectory() as temp, patch.object(run, "OUTPUT", Path(temp)), \
                 patch.object(run, "discover", return_value=targets), \
                 patch.object(run, "build", return_value=Path("app")) as build, \
                 patch.object(run, "choose", side_effect=lambda choices: choices) as choose, \
                 patch.object(run, "install") as install:
                self.assertEqual(run.main(platform), 0)
                build.assert_called_once_with(platform)
                choose.assert_called_once_with(expected)
                self.assertEqual(install.call_count, len(expected))

    def test_no_ios_devices_skips_picker_and_install(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(run, "OUTPUT", Path(temp)), \
             patch.object(run, "discover", return_value=[{"kind": "mac"}]), \
             patch.object(run, "build", return_value=Path("app")), \
             patch.object(run, "choose") as choose, patch.object(run, "install") as install:
            self.assertEqual(run.main("ios"), 0)
            choose.assert_not_called()
            install.assert_not_called()

    def test_picker_all_cancel_and_duplicate_names(self):
        targets = [{"name": "Device", "id": "a"}, {"name": "Device", "id": "b"}]
        for output, expected in [(run.ALL, targets), ("", []), ("2. Device", targets[1:])]:
            with patch.object(run.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, output, "")):
                self.assertEqual(run.choose(targets), expected)

    def test_failed_build_never_prompts_or_installs(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(run, "OUTPUT", Path(temp)), \
             patch.object(run, "discover", return_value=[{"kind": "mac"}]), \
             patch.object(run, "build", side_effect=RuntimeError("build failed")), \
             patch.object(run, "choose") as choose, patch.object(run, "install") as install:
            with self.assertRaises(RuntimeError):
                run.main()
            choose.assert_not_called()
            install.assert_not_called()

    def test_cancel_never_installs(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(run, "OUTPUT", Path(temp)), \
             patch.object(run, "discover", return_value=[{"kind": "mac"}]), \
             patch.object(run, "build", return_value=Path("app")), \
             patch.object(run, "choose", return_value=[]), patch.object(run, "install") as install:
            self.assertEqual(run.main(), 0)
            install.assert_not_called()

    def test_install_failure_does_not_skip_remaining_devices(self):
        targets = [{"kind": "mac", "name": "Computer"}, {"kind": "ios", "name": "Device"}]
        with tempfile.TemporaryDirectory() as temp, patch.object(run, "OUTPUT", Path(temp)), \
             patch.object(run, "discover", return_value=targets), \
             patch.object(run, "build", return_value=Path("app")), \
             patch.object(run, "choose", return_value=targets), \
             patch.object(run, "install", side_effect=[RuntimeError("unreachable"), None]) as install:
            self.assertEqual(run.main(), 1)
            self.assertEqual(install.call_count, 2)


if __name__ == "__main__":
    unittest.main()
