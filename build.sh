#!/usr/bin/env bash

set -euo pipefail

_root_dir="$(dirname "$(greadlink -f "$0")")"
source "$_root_dir/devutils/shared.sh"
_download=false
while getopts 'd' option; do
  case "$option" in
    d) _download=true ;;
    *) echo "Usage: $0 [-d] [arm64|x86_64]" >&2; exit 2 ;;
  esac
done
shift "$((OPTIND - 1))"

_arch="${1:-arm64}"
case "$_arch" in
  arm64|x86_64) ;;
  *) echo "Usage: $0 [-d] [arm64|x86_64]" >&2; exit 2 ;;
esac

if [ "$_download" = true ]; then
  prepare_sources "$_arch" true
  configure_build "$_arch" false false
else
  prepare_sources "$_arch" false
  configure_build "$_arch" false true
fi

helium_build chrome/installer/mac
"$_root_dir/sign_and_package_app.sh"
