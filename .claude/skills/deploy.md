---
description: Build, deploy, and run Anvil on the connected iPhone via xtool
user-invocable: true
---

# Deploy to Device

Run these steps in order from the project root:

1. **Compile check**: `swift build --swift-sdk arm64-apple-ios` — fast cross-compile to catch errors without needing the device.
2. **If compilation fails**, fix the errors and re-run step 1. Do not proceed until it compiles.
3. **Deploy**: `LD_LIBRARY_PATH="$(swiftly use --print-location)/usr/lib/swift/linux" xtool dev` — builds, signs, installs, and verifies on the connected iPhone. (If `swiftly` isn't on PATH, point `LD_LIBRARY_PATH` at your active Swift toolchain's `usr/lib/swift/linux` directory.)
4. **Report** the result to the user — whether it succeeded or failed.

## Available xtool commands for reference
- `xtool devices` — list connected iOS devices
- `xtool dev` — debug build + deploy to device
- `xtool dev -c release` — release build + deploy
- `xtool launch com.guitaripod.anvil` — launch the installed app
- `xtool install <path.ipa>` — install an IPA file
