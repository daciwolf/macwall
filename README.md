# MacWall

MacWall is a native macOS wallpaper application in progress, built specifically for Apple desktops instead of being a cross-platform port. The product goal is to let users run high-quality animated wallpapers, manage them per display and Space, and share them with other users through a secure distribution platform.

## Why This Exists

> "Give me 6 hours to write software, and I'll spend the first 4 configuring my desktop. The last 2 are spent on Codex."
>
> some Arch Linux user, probably

I got annoyed that there was no free Wallpaper Engine alternative for macOS, so I started building this while studying for finals and playing Marvel Rivals.

## Product Direction

- Native macOS client built with `Swift`, `SwiftUI`, and targeted `AppKit` integrations where macOS window management requires it.
- Video wallpapers are a first-class feature. The initial media target is hardware-accelerated `H.264` and `HEVC` playback via Apple media frameworks.
- Apple Human Interface Guidelines should drive navigation, settings, permissions, and system integration.
- Security is a primary requirement: no arbitrary executable wallpaper packages, strict media validation, signed releases, hardened runtime, and notarized distribution.

## Planned Experience

- Animated desktop wallpapers across one or more monitors
- Wallpaper playlists, categories, previews, and performance controls
- Community sharing with uploads, moderation, search, ratings, and downloads
- Battery and thermal awareness so playback can pause or downgrade when needed

## Architecture Snapshot

- `Sources/MacWallApp/`: SwiftUI macOS app prototype
- `Sources/MacWallCore/`: wallpaper manifest validation, playback policy, and display assignment logic
- `sharing backend`: planned authenticated uploads, metadata, moderation pipeline, storage, and CDN delivery
- `release pipeline`: planned Developer ID signing, notarization, DMG creation, and update delivery

## Current Implementation

- ships with two bundled default wallpapers based on VTF5 footage, credited to `UCI Rocket Project`
- native SwiftUI app prototype with local video import, looping preview playback, and experimental desktop-level wallpaper windows
- per-display assignment logic with playback policy controls for battery, thermal pressure, Low Power Mode, and fullscreen conditions
- experimental lock-screen path via `MacWallScreenSaver.saver`, which reads the selected wallpaper from `~/Library/Application Support/MacWall/shared-state.json`
- CSV power logging at `~/Library/Application Support/MacWall/power-log.csv`
- platform-independent core models and policy logic with a repository-local test harness

## Development Commands

- `zsh scripts/test_core.sh`
  - compiles and runs the core validation and playback tests
- `swift build --disable-sandbox`
  - builds the macOS app prototype
- `zsh scripts/build_saver.sh`
  - builds the experimental screen saver bundle for lock-screen use
- `zsh scripts/build_dmg.sh`
  - builds the app, bundles the screen saver, and creates `MacWall-experimental.dmg` at the repository root

## Test Flow

1. Launch `MacWallApp`
2. Import a local `H.264` or `HEVC` `.mp4` or `.mov`
3. Enable `Enable experimental desktop wallpaper windows`
4. Install `dist/MacWallScreenSaver.saver` and select it in System Settings > Screen Saver
5. Review `~/Library/Application Support/MacWall/power-log.csv` after running the app

## Immediate Next Step

Tighten the experimental renderer into a more production-ready macOS integration:

1. persist assignments and playback state across relaunches
2. handle display hot-plug, sleep/wake, and fullscreen detection automatically
3. profile energy use with Instruments and reduce decode overhead further
4. add secure sharing backend and signed/notarized release automation
