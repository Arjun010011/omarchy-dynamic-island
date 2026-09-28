#!/bin/bash
# Copy the working tree into Omarchy's plugin folder. The shell hot-reloads
# plugins when files there change, so re-run this after every edit.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
id="$(jq -r .id "$here/manifest.json")"
target="$HOME/.config/omarchy/plugins/$id"
mkdir -p "$target"
rsync -a --delete --exclude .git --exclude dev-install.sh --exclude screenshots "$here/" "$target/"
omarchy plugin validate "$target"
echo "synced to $target"
