#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
dist_root="$repo_root/dist"
source_root="$repo_root/packaging/MacWallScreenSaver"
bundle_root="$dist_root/MacWallScreenSaver.saver"
contents_root="$bundle_root/Contents"
macos_root="$contents_root/MacOS"

/bin/rm -rf "$bundle_root"
/bin/mkdir -p "$macos_root" "$contents_root/Resources"

/bin/cp "$source_root/Info.plist" "$contents_root/Info.plist"

/usr/bin/xcrun clang \
  -fobjc-arc \
  -mmacosx-version-min=14.0 \
  -framework Cocoa \
  -framework ScreenSaver \
  -framework AVFoundation \
  -framework CoreMedia \
  -framework QuartzCore \
  -I "$source_root" \
  -bundle \
  "$source_root/MacWallScreenSaverView.m" \
  -o "$macos_root/MacWallScreenSaver"

/usr/bin/codesign --force --deep -s - "$bundle_root"

/bin/echo "Created $bundle_root"
