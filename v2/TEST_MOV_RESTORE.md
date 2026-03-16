# Re-adding `test.mov`

`test.mov` was the manual proof-of-life asset for the private aerial path. It has been removed from the live Apple wallpaper store, but these are the exact changes needed to add it back.

## Files

- Video: `~/Library/Application Support/com.apple.wallpaper/aerials/videos/test.mov`
- Thumbnail: `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/test.png`
- Catalog: `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`
- Bundle archive: `~/Library/Application Support/com.apple.wallpaper/aerials/manifest.tar`

## Manifest entry

Append an asset entry like this to `entries.json`, using the next available `preferredOrder`:

```json
{
  "accessibilityLabel": "test",
  "categories": [
    "A33A55D9-EDEA-4596-A850-6C10B54FBBB5"
  ],
  "id": "test",
  "includeInShuffle": false,
  "localizedNameKey": "test",
  "pointsOfInterest": {},
  "preferredOrder": 0,
  "previewImage": "file:///Users/daciwolf/Library/Application%20Support/com.apple.wallpaper/aerials/thumbnails/test.png",
  "shotID": "MACWALL_TEST",
  "showInTopLevel": true,
  "subcategories": [
    "78D1B993-DA5B-4CA6-90F0-865DA7F9091D"
  ],
  "url-4K-SDR-240FPS": "file:///Users/daciwolf/Library/Application%20Support/com.apple.wallpaper/aerials/videos/test.mov"
}
```

The category/subcategory IDs above were taken from the existing Apple manifest and were reused during the successful manual test.

## Activation steps

1. Copy `test.mov` into `~/Library/Application Support/com.apple.wallpaper/aerials/videos/`.
2. Copy `test.png` into `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/`.
3. Add the manifest entry to `entries.json`.
4. Rebuild `manifest.tar` from the manifest directory contents:

```bash
tar -cf ~/Library/Application\ Support/com.apple.wallpaper/aerials/manifest.tar \
  -C ~/Library/Application\ Support/com.apple.wallpaper/aerials/manifest \
  entries.json \
  TVIdleScreenStrings.bundle
```

5. Point `SystemWallpaperURL` at the MOV if you want it active immediately:

```bash
defaults write com.apple.wallpaper SystemWallpaperURL -string \
  "file:///Users/daciwolf/Library/Application%20Support/com.apple.wallpaper/aerials/videos/test.mov"
```

6. Restart the wallpaper agent:

```bash
killall WallpaperAgent
```

The app in `v2/` now automates this same flow for app-managed assets.
