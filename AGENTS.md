# Magnet Relay

Magnet Relay sends magnet links from Safari to qBittorrent on a local server.

## Development

- Create the ignored `local.xcconfig` shown under Repository Rules.
- Open `Magnet Relay.xcodeproj` in Xcode.
- Run the macOS or iOS target.
- Use the native app to test the qBittorrent connection.
- The Codex **Run** action builds Release apps for macOS and physical iOS devices, then displays a device picker with names, multiple selection, and **All available devices**.
- Physical iOS devices must be paired and available to Xcode. USB and wireless devices are discovered again after the builds finish.
- Build output stays in ignored `.derivedData/run/` logs; the terminal shows progress and bounded failure summaries.
- Installation starts only after choosing **Install**. The Mac app is installed in `~/Applications`. Apps are not launched.
- Run the workflow from a terminal with `python3 scripts/run.py`.

## Behavior

Safari opens the native app for magnet links on iOS and macOS. The app adds the torrent, displays the result, and opens the server after success. On macOS, it then quits automatically. It also shows connection details and provides Refresh and Open controls. The server address is editable, starts with `192.168.1.`, and is saved on the device when editing finishes.

## Security

The app uses the registered `magnet:` URL scheme without website access. Network requests come from native app code. API requests use Bearer authentication when a key is configured for the selected server. The personal app bundle includes that key; do not distribute the bundle. Use HTTPS on untrusted networks.

## Repository Rules

- This is personal, local-only software, not for App Store distribution.
- Keep the Codex Run action configured for quiet Release builds followed by named device selection, including this Mac, all available physical iOS devices, and an install-to-all option. Do not build for or install on simulators.
- Keep the API key and its server host, signing, server scheme, and server port settings in the ignored `local.xcconfig`; store the editable server address in device preferences:

  ```xcconfig
  MAGNET_RELAY_DEVELOPMENT_TEAM = YOUR_TEAM_ID
  MAGNET_RELAY_APP_BUNDLE_IDENTIFIER = com.example.MagnetRelay
  MAGNET_RELAY_SERVER_SCHEME = http
  MAGNET_RELAY_SERVER_PORT = YOUR_SERVER_PORT
  MAGNET_RELAY_API_KEY = YOUR_API_KEY
  MAGNET_RELAY_API_KEY_HOST = YOUR_SERVER_HOST
  ```
