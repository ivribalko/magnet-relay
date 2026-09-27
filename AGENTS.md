# Magnet Relay

Magnet Relay sends magnet links from Safari to qBittorrent on a local server.

## Development

- Create the ignored `local.xcconfig` shown under Repository Rules.
- Open `Magnet Relay.xcodeproj` in Xcode.
- Run the macOS or iOS target.
- Use the native app to test the qBittorrent connection.

## Behavior

Safari opens the native app for magnet links on iOS and macOS. The app adds the torrent, displays the result, and opens the server after success. On macOS, it then quits automatically. It also shows connection details and provides Refresh and Open controls. The server address is editable, starts with `192.168.1.`, and is saved on the device when editing finishes.

## Security

The app uses the registered `magnet:` URL scheme without website access. Network requests come from native app code. Use HTTPS on untrusted networks.

## Repository Rules

- This is personal, local-only software, not for App Store distribution.
- Keep signing, server scheme, and server port settings in the ignored `local.xcconfig`; store the editable server address in device preferences:

  ```xcconfig
  MAGNET_RELAY_DEVELOPMENT_TEAM = YOUR_TEAM_ID
  MAGNET_RELAY_APP_BUNDLE_IDENTIFIER = com.example.MagnetRelay
  MAGNET_RELAY_SERVER_SCHEME = http
  MAGNET_RELAY_SERVER_PORT = YOUR_SERVER_PORT
  ```
