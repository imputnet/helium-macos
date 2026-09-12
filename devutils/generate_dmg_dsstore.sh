#!/bin/bash -eu

# Regenerates resources/dmg_dsstore (window layout used by pkg-dmg) from
# resources/dmg.json by extracting the .DS_Store from a throwaway appdmg image.

_resources="$(dirname "$(dirname "$(greadlink -f "${BASH_SOURCE[0]}")")")/resources"

_tmp="$(mktemp -d)"
trap 'hdiutil detach "$_tmp/mnt" -quiet 2>/dev/null' EXIT

# Stub bundle is enough, the .DS_Store only records file names
mkdir -p "$_tmp/Helium.app/Contents/Resources" "$_tmp/mnt"
cp "$_resources/assets/app.icns" "$_tmp/Helium.app/Contents/Resources/"
ln -s "$_resources/dmg.json" "$_resources/dmg_background.png" "$_tmp/"

npx -y appdmg@0.6.6 "$_tmp/dmg.json" "$_tmp/layout.dmg"

hdiutil attach "$_tmp/layout.dmg" -mountpoint "$_tmp/mnt" -readonly -nobrowse -quiet
cp "$_tmp/mnt/.DS_Store" "$_resources/dmg_dsstore"
