# Magnet Relay

Magnet Relay sends magnet links from Safari to qBittorrent on a local server.

## Development

- Create the ignored `local.xcconfig` shown under Repository Rules.
- Open `Magnet Relay.xcodeproj` in Xcode.
- Run the macOS or iOS target.
- Use the native app to test the qBittorrent connection.

## Behavior

Safari opens the native app for magnet links on iOS and macOS. The app adds the torrent, displays the result, and opens the server after success. It also shows connection details and provides Refresh and Open controls.

## Security

The app uses the registered `magnet:` URL scheme without website access. Network requests come from native app code. Use HTTPS on untrusted networks.

## Repository Rules

- This is personal, local-only software, not for App Store distribution.
- Keep signing and server settings only in the ignored `local.xcconfig`:

  ```xcconfig
  MAGNET_RELAY_DEVELOPMENT_TEAM = YOUR_TEAM_ID
  MAGNET_RELAY_APP_BUNDLE_IDENTIFIER = com.example.MagnetRelay
  MAGNET_RELAY_SERVER_SCHEME = http
  MAGNET_RELAY_SERVER_HOST = YOUR_SERVER_HOST
  MAGNET_RELAY_SERVER_PORT = YOUR_SERVER_PORT
  ```
