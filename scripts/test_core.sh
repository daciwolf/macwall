#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
build_dir="$repo_root/.build/tests"
module_cache_dir="$repo_root/.build/ModuleCache.noindex"

/bin/mkdir -p "$build_dir"
/bin/mkdir -p "$module_cache_dir"

/usr/bin/env CLANG_MODULE_CACHE_PATH="$module_cache_dir" /usr/bin/swiftc \
  "$repo_root"/Sources/MacWallCore/*.swift \
  "$repo_root"/Tests/CoreTestMain.swift \
  -o "$build_dir/macwall-core-tests"

"$build_dir/macwall-core-tests"
