# Anvil — iOS qBittorrent Client

## Stack
- Swift 6, UIKit, programmatic UI only
- iOS 17+
- Built and deployed from Linux via xtool + SwiftPM
- No Xcode, no Interface Builder, no storyboards, no xibs

## Architecture
- UIKit app with UIApplicationDelegate + UIWindowSceneDelegate
- Scene-based lifecycle (UISceneConfiguration)
- All UI is programmatic — no IB, no storyboards

## UIKit Rules — Modern APIs Only
- UIButton.Configuration for all buttons, never setTitle/setImage
- UIAction closures for all control events, never #selector/@objc target-action
- UICollectionView with compositional layout + diffable data source for all lists/grids
- UIContentConfiguration for cell content, never manual subview layout in cells
- No UITableView — use UICollectionView with list layout instead
- No #selector, no @objc unless strictly required by a system API with no alternative
- Prefer UIStackView for all multi-view layouts. Only use raw constraints when stack views can't express the layout (e.g., aspect ratio constraints, overlay positioning)

## Build & Deploy
- `swift build --swift-sdk arm64-apple-ios` — cross-compile check after every change (~0.1s, no device needed)
- xtool needs the swiftly toolchain's runtime on `LD_LIBRARY_PATH` (see `.claude/skills/deploy.md`)
- At the end of each task, use the `/deploy` skill to compile-check and install to the connected iPhone
- Bundle ID: com.guitaripod.anvil

## Backend
- qBittorrent Web API v2 (https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-5.0))
- Target server: qbittorrent-nox 5.x
- Auth: cookie session via POST /api/v2/auth/login (form: username, password). Cookie `QBT_SID_<port>` is held by the APIClient's ephemeral URLSession
- The `Referer` header MUST match the WebUI base URL on login
- v5+ uses `/torrents/stop` and `/torrents/start` (the legacy `pause`/`resume` endpoints return 404)
- Periodic refresh: GET /torrents/info + /transfer/info every 2s when foregrounded
- Password stored in Keychain; base URL + username in UserDefaults

## Code Style
- No code comments
- No file headers
- No storyboards, no xibs, no Interface Builder
- Programmatic Auto Layout via NSLayoutConstraint or layout anchors
- async/await and structured concurrency for networking
- Observation framework over KVO/NotificationCenter where applicable

## Logging
- Never use `print()` — it does not appear in xtool device logs
- Use `os.log` (import os) or `NSLog` for all debug/diagnostic output
- os.log preferred: `import os; Logger(subsystem: "com.guitaripod.anvil", category: "networking").info("message")`
