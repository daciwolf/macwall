# MacWall v2

`v2/` is a custom-aerial manager for Apple’s private wallpaper pipeline.

It imports compatible videos, creates a backup of Apple’s current aerial manifest state, copies the video and thumbnail into the user aerial store, appends the new asset under the `Mac` wallpaper category, and can activate the selected asset by writing `SystemWallpaperURL` and restarting `WallpaperAgent`.

## Current understanding

- The public wallpaper API is not the moving-wallpaper path.
- Apple’s aerial system reads user-level assets from `~/Library/Application Support/com.apple.wallpaper/aerials/`.
- Custom assets can be added safely only if the manifest editor preserves Apple’s existing JSON structure and only appends the new asset entry.

## What the app does

- imports videos into `~/Library/Application Support/MacWallV2/ImportedVideos/<UUID>/`
- preserves working `.mov` files as-is during import
- converts non-`.mov` video inputs into `.mov`
- creates timestamped backups of:
  - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`
  - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest.tar`
- installs app-managed aerial assets into:
  - `~/Library/Application Support/com.apple.wallpaper/aerials/videos/`
  - `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/`
  - `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`
- appends new assets under Apple’s `Mac` wallpaper category instead of the landscape or space categories
- rebuilds `~/Library/Application Support/com.apple.wallpaper/aerials/manifest.tar`
- can activate an installed asset by updating `com.apple.wallpaper` `SystemWallpaperURL`
- can restore the original `SystemWallpaperURL` without deleting the installed custom asset library
- can remove app-managed assets from the manifest, thumbnail cache, and video cache

## Build

```bash
cd v2
swift build
swift run MacWallV2
swift test
```

Run it as your normal user. Do not use `sudo`, because the app reads and writes the wallpaper store under `~/Library/Application Support/com.apple.wallpaper/`.
