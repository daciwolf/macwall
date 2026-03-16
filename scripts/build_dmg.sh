#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
build_root="$repo_root/.build"
dist_root="$repo_root/dist"
bundle_root="$dist_root/MacWall.app"
contents_root="$bundle_root/Contents"
macos_root="$contents_root/MacOS"
dmg_staging_root="$dist_root/dmg-root"
dmg_name="${MACWALL_DMG_NAME:-MacWall-experimental-20260315.dmg}"
dmg_path="$repo_root/$dmg_name"
saver_bundle_root="$dist_root/MacWallScreenSaver.saver"
bundled_wallpapers_root="$repo_root/Sources/MacWallApp/Resources/BundledWallpapers"

swift_build_env=(
  /usr/bin/env
  PATH="/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin"
  HOME="$repo_root"
  SWIFTPM_CUSTOM_CACHE_PATH="$build_root/swiftpm-cache"
  CLANG_MODULE_CACHE_PATH="$build_root/ModuleCache.noindex"
)

/bin/mkdir -p "$build_root/ModuleCache.noindex"

"${swift_build_env[@]}" /usr/bin/swift build --disable-sandbox -c release

app_binary_path="$("${swift_build_env[@]}" /usr/bin/swift build --disable-sandbox -c release --show-bin-path)/MacWallApp"

"$repo_root/scripts/build_saver.sh"

/bin/rm -rf "$bundle_root" "$dmg_staging_root" "$dmg_path"
/bin/mkdir -p "$macos_root" "$contents_root/Resources" "$dmg_staging_root"

/bin/cp "$repo_root/packaging/MacWall-Info.plist" "$contents_root/Info.plist"
/bin/cp "$app_binary_path" "$macos_root/MacWallApp"
/bin/cp -R "$bundled_wallpapers_root" "$contents_root/Resources/BundledWallpapers"
/bin/cp -R "$saver_bundle_root" "$contents_root/Resources/MacWallScreenSaver.saver"
/bin/chmod +x "$macos_root/MacWallApp"

/usr/bin/codesign --force --deep -s - "$bundle_root"

/bin/cp -R "$bundle_root" "$dmg_staging_root/MacWall.app"
/bin/cp -R "$saver_bundle_root" "$dmg_staging_root/MacWallScreenSaver.saver"
/bin/ln -s /Applications "$dmg_staging_root/Applications"

/usr/bin/hdiutil create \
  -volname "MacWall Experimental" \
  -srcfolder "$dmg_staging_root" \
  -ov \
  -format UDZO \
  "$dmg_path"

/bin/echo "Created $dmg_path"
