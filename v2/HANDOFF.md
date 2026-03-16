# MacWall v2 Handoff

Date: 2026-03-15

## Current state

`v2/` is a focused app-managed wrapper around Apple’s private aerial wallpaper store.

The earlier manifest writer bug was narrowed down: the failure came from decoding Apple’s manifest into a reduced Swift model and writing it back out, which dropped Apple-owned keys and newer default data. The corrected direction is to mutate the manifest as raw JSON, keep Apple’s existing shape intact, and only append custom `Mac` category assets after first creating backups.

## Confirmed findings

- `NSWorkspace.shared.setDesktopImageURL(...)` is still the wrong API for real moving wallpapers.
- Apple’s aerial system reads user-level assets from:
  - `~/Library/Application Support/com.apple.wallpaper/aerials/videos/`
  - `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/`
  - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`
  - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest.tar`
- A manually added `test.mov` asset was previously confirmed to work through that private path on this machine.
- The `Mac` wallpaper category in the live manifest is:
  - category ID `8048287A-39E6-4093-87EC-B0DCE7CB4A29`
  - subcategory ID `989909D1-AEFC-4BE5-9249-ABFBA5CABED0`
- Apple’s live manifest includes additional top-level metadata and asset/category fields that must not be discarded.

## What changed in the app

- The private aerial install and activation flow is back, but now routes through a raw JSON manifest editor.
- `CustomAerialService` now creates timestamped backups before rewriting `entries.json` and `manifest.tar`.
- New custom assets are added under the Apple `Mac` wallpaper category rather than the landscape fallback.
- Thumbnail generation is part of install and writes PNGs into Apple’s `thumbnails` directory.
- `ImportedVideoStore` still preserves working `.mov` inputs as-is instead of always re-exporting them.

## Important files

- `v2/Sources/MacWallV2/AppModel.swift`
- `v2/Sources/MacWallV2/ContentView.swift`
- `v2/Sources/MacWallV2/CustomAerialService.swift`
- `v2/Sources/MacWallV2/ImportedVideoStore.swift`
- `v2/Sources/MacWallV2/AerialAssetIdentity.swift`
- `v2/TEST_MOV_RESTORE.md`

## Manual `test.mov`

The exact steps and manifest shape used during the original experiment are still documented in `v2/TEST_MOV_RESTORE.md`. The app now aims to automate that workflow safely for the `Mac` category.

## Next practical work

- Verify the raw JSON writer keeps Apple’s non-custom entries intact after install and remove operations.
- Verify the refactored app builds and runs cleanly against the live user wallpaper store.
- If category placement needs refinement, inspect how System Settings groups custom `Mac` assets after activation.
