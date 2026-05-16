# Anvil

A native iOS qBittorrent client, built on Arch Linux.

![Swift](https://img.shields.io/badge/Swift_6-F05138?style=flat&logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/iOS_17+-000000?style=flat&logo=apple&logoColor=white)
![UIKit](https://img.shields.io/badge/UIKit-2396F3?style=flat&logo=apple&logoColor=white)
![xtool](https://img.shields.io/badge/xtool-FF6B35?style=flat&logo=hammer&logoColor=white)
![qBittorrent](https://img.shields.io/badge/qBittorrent-2F67BA?style=flat&logo=qbittorrent&logoColor=white)

Pure programmatic UIKit, cross-compiled from Linux to iOS, deployed to iPhone over USB. No Xcode, no macOS, no storyboards.

## Stack

| | |
|---|---|
| Language | Swift 6, strict concurrency |
| UI | UIKit — compositional layouts, diffable data sources, content configurations |
| Build | SwiftPM, `swift build --swift-sdk arm64-apple-ios` |
| Deploy | [xtool](https://github.com/xtool-org/xtool) |
| Backend | qBittorrent Web API v2 (cookie session, JSON polling) |

## Build

```bash
swift build --swift-sdk arm64-apple-ios
```

## Deploy

```bash
xtool dev
```

## Architecture

```
Sources/Anvil/
├── App/         AppDelegate, SceneDelegate, ServerBootstrap
├── Networking/  APIClient (actor), QBitEndpoint, QBitModels, KeychainHelper
├── Settings/    ServerSetup, Settings
├── Torrents/    List, filter chips, cell, stats bar
├── Detail/      Torrent detail, files, trackers
├── Add/         Add torrent
└── Shared/      Theme, TabBar, Formatters, ProgressBar
```

Zero dependencies. Foundation + UIKit + Security.
