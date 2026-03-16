# Repository Guidelines

## Project Structure & Module Organization
The repository is split into a native app shell and a testable core:

- `Sources/MacWallApp/` contains the SwiftUI macOS application prototype
- `Sources/MacWallCore/` contains platform-independent wallpaper models and business logic
- `Tests/` contains the repository-local core test harness
- `scripts/` contains build and test helper scripts
- `plan.md` captures the product and architecture roadmap

Keep new logic in `MacWallCore` unless it depends directly on `SwiftUI`, `AppKit`, or macOS system APIs.

## Build, Test, and Development Commands
Use repository-local scripts first:

- `zsh scripts/test_core.sh` compiles and runs the core validation and policy tests

Native app development currently assumes a matching Apple toolchain. Once full Xcode is configured, add the Xcode project or workspace to the repo and document the exact build command here.

## Coding Style & Naming Conventions
Use `Swift` naming conventions:

- `PascalCase` for types
- `camelCase` for properties and functions
- one type per file when practical

Keep core types `Sendable` where reasonable, prefer immutable models, and keep macOS-specific imports out of `MacWallCore`.

## Testing Guidelines
Core logic should stay testable without UI dependencies. Add coverage for:

- wallpaper manifest validation
- playback policy decisions
- display assignment behavior

Follow the existing plain-language test naming pattern in `Tests/CoreTestMain.swift`, for example `testBatteryAndLowPowerReducePlayback`.

## Commit & Pull Request Guidelines
Use short imperative commits with a prefix, for example `feat: add playback policy engine` or `fix: reject invalid wallpaper preview formats`.

Pull requests should include:

- a short summary of user-facing impact
- validation steps run locally
- screenshots for macOS UI changes
- notes on security-sensitive changes, especially around package parsing, media handling, or sharing

## Security & Configuration Tips
Do not add executable wallpaper formats, script runtimes, or broad filesystem entitlements without updating the threat model in `plan.md`. Treat uploaded wallpaper metadata and media as untrusted input.
