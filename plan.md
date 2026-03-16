# MacWall Plan

## 0. Current Integrated Plan

This repository now targets a single combined architecture:

- `MacWallApp` remains the primary logged-in experience.
- The main window, sidebar, wallpaper detail UI, and desktop renderer window stay in the main app.
- While the user is logged in, MacWall shows the chosen wallpaper through its own desktop-level renderer windows.
- For the lock screen and the underlying system wallpaper path, MacWall uses Apple’s private aerial store under `~/Library/Application Support/com.apple.wallpaper/aerials/`.

The important split is:

- `Logged in desktop`: rendered by MacWall’s own windows so the app can keep its richer UI and desktop behavior.
- `Lock screen / underlying system wallpaper`: written through the safer aerial installer path so the selected video can appear in Apple’s wallpaper system.

### 0.1 Runtime model

When a user imports a wallpaper and selects it in the main app:

1. The main app stores the wallpaper in MacWall-managed application support storage.
2. The desktop renderer uses that imported local video for the logged-in desktop session.
3. The lock-screen section can apply either:
   - the same wallpaper as the desktop selection, or
   - a different imported wallpaper dedicated to the lock screen.
4. Applying the lock-screen wallpaper copies the video into Apple’s aerial store, generates or converts a thumbnail, appends a `Mac` category asset to Apple’s manifest, rebuilds `manifest.tar`, and updates `SystemWallpaperURL`.
5. When the screen locks, the underlying Apple wallpaper path is already pointing at the installed lock-screen asset.

### 0.2 Lock-screen install path

The lock-screen path must always behave in this order:

1. Resolve the selected lock-screen wallpaper from the main app selection model.
2. Require a real local video file. Bundled/demo-only entries that do not have a local video file cannot be installed to the lock screen.
3. Create timestamped backups of the current Apple wallpaper system files before any mutation.
4. Copy the selected video into:
   - `~/Library/Application Support/com.apple.wallpaper/aerials/videos/`
5. Write a PNG thumbnail into:
   - `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/`
6. Append or update a single custom asset inside Apple’s `Mac` wallpaper category in:
   - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`
7. Rebuild:
   - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest.tar`
8. Point `com.apple.wallpaper` `SystemWallpaperURL` at the installed video.
9. Restart `WallpaperAgent`.

The `Mac` category identifiers currently used by the implementation are:

- category ID `8048287A-39E6-4093-87EC-B0DCE7CB4A29`
- subcategory ID `989909D1-AEFC-4BE5-9249-ABFBA5CABED0`

### 0.3 Backup policy

Backups of Apple-managed wallpaper files are mandatory. The app must never rewrite the aerial manifest without first creating timestamped copies of:

- `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`
- `~/Library/Application Support/com.apple.wallpaper/aerials/manifest.tar`

The backup rules are:

- backups are created before every manifest rewrite
- backups use timestamped `.bak.*` file names
- the original `SystemWallpaperURL` is recorded in MacWall state before the first activation
- restoring the original wallpaper resets `SystemWallpaperURL` but does not delete the app-managed custom aerial assets unless explicit cleanup is added later

### 0.4 Manifest safety rule

MacWall must not decode Apple’s aerial manifest into a reduced typed model and write it back out.

Instead:

- the manifest is parsed as raw JSON
- Apple-owned top-level keys and unrelated asset/category fields are preserved
- only the app-managed asset entry is appended, replaced, or removed
- the `Mac` category placement is explicit and never guessed from landscape, earth, or city categories

### 0.5 Main app UI plan

The main app UI remains the primary control surface:

- sidebar and wallpaper detail remain in `MacWallApp`
- desktop renderer controls remain in the main app
- the old screen-saver workaround section is replaced by a lock-screen section
- the lock-screen section exposes:
  - same as desktop vs different wallpaper
  - apply to lock screen
  - restore original system wallpaper
  - current `SystemWallpaperURL`
  - diagnostic path to MacWall’s lock-screen state file

### 0.6 Implementation checklist

- Keep the logged-in renderer and main app window from the existing main app.
- Move the safe aerial manifest writer pattern into the main app target.
- Restrict lock-screen install to wallpapers with a local imported video file.
- Always create backups before mutating Apple’s wallpaper files.
- Keep the desktop renderer independent from the lock-screen installer so the logged-in presentation layer does not depend on Apple’s private wallpaper playback.

## 1. Product Goal

MacWall should be a native macOS wallpaper platform for Apple Silicon and modern Intel Macs that delivers animated and video wallpapers with the polish, efficiency, and system integration users expect from a Mac app. The product should feel native, avoid unsafe plugin-style content, and support a creator ecosystem where wallpapers can be uploaded, moderated, discovered, and installed from inside the app.

The app is not just a local wallpaper player. It is a combined desktop client, content format, and online distribution platform with a strong security posture.

## 2. Product Principles

- Native first: build for macOS directly with Apple frameworks instead of wrapping a web or game engine shell.
- Apple UX: follow Human Interface Guidelines for navigation, settings, permissions, menus, and background behavior.
- Secure by default: wallpapers are media packages, not executable bundles.
- Predictable performance: the app must respect battery, thermal, and fullscreen conditions.
- Creator friendly: publishing and sharing should be built into the platform, not bolted on later.

## 3. Target Scope

### In scope for v1

- Native macOS desktop app
- Local wallpaper import and management
- Video wallpapers
- Community accounts, uploads, downloads, and moderation
- Per-display wallpaper assignment
- Signed, notarized DMG releases

### Out of scope for v1

- Executable wallpaper code
- Browser-based wallpaper runtimes
- User-authored shaders or scripts
- Live widgets embedded in wallpapers
- Mac App Store release

The v1 scope is intentionally narrow so the product can ship securely and reliably.

## 4. Recommended Platform Baseline

- Primary language: `Swift`
- UI stack: `SwiftUI`
- macOS integration: `AppKit`
- Media playback: `AVFoundation`
- Advanced rendering path when needed: `Metal`
- Storage for local app data: `SwiftData` or `Core Data`, to be finalized during technical discovery
- Release target: direct distribution via Developer ID signed and notarized DMG
- Recommended deployment target: `macOS 14+`

`macOS 14+` is the recommended baseline because it simplifies modern SwiftUI development, supports current Apple Silicon hardware well, and reduces compatibility work during the first release cycle.

## 5. User Stories

### End users

- Import a video file and set it as wallpaper for one display or all displays
- Browse featured and community wallpapers inside the app
- Preview wallpapers before downloading
- Pause wallpaper playback automatically on battery, low power, or fullscreen apps
- Organize favorites, recently used wallpapers, and playlists

### Creators

- Upload a wallpaper package with title, description, tags, preview media, and attribution
- Edit metadata after publishing
- Track downloads and engagement
- Respond to moderation requests or takedowns

### Moderators and operators

- Review flagged uploads
- Remove unsafe or infringing content
- Rate limit abusive accounts
- Audit upload and download activity

## 6. Functional Requirements

### Desktop experience

- Render wallpapers behind desktop icons and normal application windows
- Support multiple displays with independent wallpaper assignments
- Survive login, sleep, wake, monitor hot-plugging, and Space changes
- Restore the previous wallpaper state after app relaunch

### Playback

- Support `mp4` and `mov` in approved codecs, starting with `H.264` and `HEVC`
- Loop seamlessly where possible
- Expose mute, playback quality, and framerate limits
- Pause or downgrade playback based on battery, thermal pressure, and fullscreen detection

### Library management

- Import local files
- Store metadata, thumbnails, and checksums
- Track installed, downloaded, favorited, and creator-owned wallpapers
- Remove wallpapers cleanly without orphaned media files

### Community platform

- Account sign-in
- Upload pipeline for wallpaper packages
- Search, filtering, tags, categories, and featured lists
- Ratings, favorites, reporting, and moderation workflows

## 7. Non-Functional Requirements

- The app should remain responsive while rendering wallpapers
- Idle CPU usage should stay low during looped playback
- Memory growth should remain bounded over long sessions
- Security controls should assume untrusted uploads and hostile clients
- The app should degrade gracefully when media is unsupported or corrupted

## 8. Native macOS Architecture

### 8.1 App structure

The client should be split into these major modules:

- `App Shell`: launch flow, settings, menu bar integration, permissions, login behavior
- `Desktop Renderer`: creates and manages wallpaper windows for each display
- `Playback Engine`: controls media loading, looping, mute, pause, and performance state
- `Library Manager`: local metadata, import, install, delete, cache, and thumbnails
- `Sync and Community Client`: authentication, browsing, download, upload, reporting
- `Security Layer`: package validation, checksums, Keychain access, signature verification for updates

### 8.2 Desktop rendering strategy

This is the highest-risk native integration area and should be validated first.

Proposed approach:

- Create one wallpaper window per active display
- Use borderless, non-activating windows managed with `AppKit`
- Position those windows at the desktop layer behind standard app windows
- Track display changes with `NSScreen`, `CGDirectDisplay`, and workspace notifications
- Recreate or rebind renderer windows when Spaces, monitors, or fullscreen state changes

The technical discovery phase should confirm whether a stable desktop-level window strategy works across:

- Finder desktop icons
- Mission Control
- Stage Manager
- Full-screen apps
- Multiple monitors with mixed resolutions
- Sleep and wake transitions

If the window-layer approach is unreliable, the backup plan is to restrict some behaviors in v1 rather than introduce a non-native runtime.

### 8.3 Playback engine

Initial playback should prioritize reliability over visual effects:

- Use `AVPlayer` and `AVPlayerLayer` or `AVSampleBufferDisplayLayer` for the first implementation
- Keep decoding hardware-accelerated when possible
- Pre-generate thumbnails and preview clips during import or after download
- Use `Metal` only for later visual processing, scaling, or transition effects if profiling proves it is needed

The first release should avoid complex effect graphs. A stable video wallpaper player is more important than advanced visual customization.

### 8.4 Local storage model

Local state should include:

- wallpaper metadata
- file paths and checksums
- preview assets
- install source
- assignment state per display
- favorites and local history
- cached remote browsing data

User data should live under the app's `Application Support` directory, with clear separation between:

- imported originals
- installed managed copies
- generated thumbnails
- cacheable remote assets
- persistent app database

## 9. Wallpaper Package Format

The package format should be intentionally restrictive.

### Proposed v1 package contents

- `manifest.json`
- `preview.jpg`
- `wallpaper.mp4` or `wallpaper.mov`
- optional `thumbnail.jpg`
- optional localized metadata files if needed later

### Manifest fields

- stable wallpaper ID
- version
- title
- author name and author ID
- description
- tags
- category
- target aspect ratios
- duration
- frame rate
- codec and resolution metadata
- checksum list for package contents
- content rating
- licensing or attribution metadata

### Package rules

- No scripts
- No dynamic libraries
- No HTML
- No nested archives
- No symlinks
- No executable permissions
- Strict file count and size limits

The server should unpack, validate, scan, and repackage uploads into a canonical internal format. The client should never trust creator-provided metadata without server validation.

## 10. Sharing Platform Architecture

### 10.1 Core services

- `API Gateway`: authenticated client entry point
- `Auth Service`: accounts, sessions, OAuth or email sign-in
- `Wallpaper Service`: metadata, search, categories, featured lists
- `Upload Service`: signed upload URLs and package intake
- `Moderation Service`: reports, queues, decisions, and audit trail
- `Media Worker`: transcoding, thumbnail generation, validation, checksum generation
- `Storage Layer`: object storage for originals and canonical media
- `CDN`: delivery of previews and download packages

### 10.2 Upload flow

1. Creator signs in.
2. Client requests an upload session.
3. Server returns a short-lived upload URL and allowed package constraints.
4. Client uploads the bundle.
5. Backend scans and validates the archive.
6. Media worker transcodes unsupported but recoverable media to approved formats.
7. Server extracts metadata, generates thumbnails, computes checksums, and stores normalized records.
8. Wallpaper enters review state before publication.

### 10.3 Download and install flow

1. User browses community wallpapers.
2. Client downloads metadata and preview assets first.
3. When user installs, client downloads the canonical package from CDN.
4. Client validates checksum and manifest rules.
5. Package is unpacked into managed application storage.
6. Wallpaper becomes available for assignment.

## 11. Security Plan

Security is a core product requirement, not a later hardening pass.

### 11.1 Threat model

Primary threats:

- malicious wallpaper uploads
- crafted media files that target parser vulnerabilities
- account abuse and spam uploads
- stolen sessions or API tokens
- tampered app updates
- privacy leakage from analytics or crash reporting

### 11.2 Client security controls

- Minimize entitlements
- Store auth tokens in Keychain
- Validate all downloaded package checksums
- Reject unsupported file types locally even after server acceptance
- Use the hardened runtime for release builds
- Sign all public builds with Developer ID
- Notarize every distributed app and DMG

### 11.3 Backend security controls

- Require authenticated uploads
- Use short-lived signed upload URLs
- Scan uploaded archives before processing
- Enforce strict MIME, extension, archive, and file count validation
- Normalize media into approved container and codec combinations
- Rate limit login, upload, report, and search endpoints
- Keep immutable moderation and audit records

### 11.4 Content and trust policy

- Start with moderated publishing, not fully open instant publishing
- Add user reporting and moderator review tools from the first public beta
- Support takedown handling and creator appeals
- Define banned content categories before opening uploads broadly

## 12. Apple UX and System Behavior

The app should feel like a Mac app, not a game launcher.

### UX guidelines

- Use standard macOS sidebar, toolbar, settings, and sheet patterns
- Keep preferences lightweight and clearly grouped
- Explain any background or login item behavior directly in the UI
- Use native file import and drag-and-drop flows
- Avoid noisy onboarding or custom chrome that conflicts with macOS conventions

### System behavior guidelines

- Respect battery and thermal conditions automatically
- Avoid stealing focus when wallpapers change
- Pause or simplify playback when a full-screen app is active
- Surface failures as clear, actionable macOS-style errors

## 13. Performance Plan

Performance targets should be set early because animated wallpapers can easily feel expensive.

### Initial targets

- Smooth playback on Apple Silicon laptops and desktops
- Low idle CPU overhead for looped video playback
- Predictable memory usage over long sessions
- Fast assignment switching between installed wallpapers

### Profiling areas

- codec choice and decode path
- multiple monitor playback
- wake-from-sleep restoration
- thumbnail generation
- cache pressure
- thermal throttling behavior

## 14. Release Engineering and DMG Distribution

### 14.1 Distribution strategy

The primary release channel should be a signed DMG downloaded directly from the project website. This keeps release control flexible and avoids forcing the first version into App Store constraints before the product behavior is proven.

### 14.2 Release pipeline

Each production build should:

1. build the release archive on a macOS runner
2. sign the app with Developer ID
3. enable hardened runtime
4. notarize the app with Apple
5. staple notarization tickets
6. package the app into a DMG
7. publish checksums and release notes

### 14.3 Updates

Post-launch auto-update support should use a signed update framework such as Sparkle, but only after the first stable DMG pipeline is working reliably.

## 15. Delivery Phases

### Phase 1: technical discovery

Deliverables:

- prototype desktop rendering approach
- playback benchmark results
- storage model decision
- package format draft
- threat model draft

Acceptance criteria:

- one document proving the windowing strategy is viable
- sample wallpapers run stably across multiple monitors

### Phase 2: local MVP

Deliverables:

- app shell
- renderer and playback engine
- local library
- settings
- import flow

Acceptance criteria:

- users can import and assign local video wallpapers
- app restores wallpaper state after relaunch

### Phase 3: private sharing alpha

Deliverables:

- auth
- upload pipeline
- moderation queue
- browse and install flow
- creator profiles

Acceptance criteria:

- invited creators can upload
- moderators can approve or reject
- approved wallpapers install correctly in the client

### Phase 4: public beta

Deliverables:

- reporting tools
- abuse controls
- download analytics
- signed DMG pipeline
- crash reporting and observability

Acceptance criteria:

- public beta can be distributed safely
- operational moderation and rollback procedures exist

### Phase 5: stable release

Deliverables:

- finalized DMG release flow
- polished onboarding and settings
- update mechanism
- support docs and legal content

Acceptance criteria:

- repeatable notarized release process
- acceptable crash rate and performance metrics

## 16. Open Questions

- Should the first release require `macOS 14+`, or is there strong value in supporting older macOS versions?
- Should uploads start as staff-curated only before creator self-service opens?
- Should the app ship with a login item in v1, or is normal launch-on-login enough?
- Should the first community release support only free wallpapers, with monetization deferred?
- Should interactive wallpapers ever exist, and if so, can they be expressed as a safe declarative scene format rather than code?

## 17. Recommended Immediate Next Steps

1. Write a separate technical specification for the desktop renderer and wallpaper window behavior.
2. Define the v1 wallpaper package schema in detail, including checksum and size rules.
3. Choose the local data layer between `SwiftData` and `Core Data`.
4. Prototype import, playback, and per-display assignment in a throwaway macOS test app.
5. Draft the backend API surface for accounts, uploads, search, moderation, and downloads.
