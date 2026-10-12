#!/usr/bin/env bash

set -euo pipefail

_root_dir="$(dirname "$(greadlink -f "$0")")"
source "$_root_dir/devutils/shared.sh"
_download=true
while getopts 'cd' option; do
  case "$option" in
    c) _download=false ;;
    d) _download=true ;;
    *) echo "Usage: $0 [-c|-d] [arm64|x86_64]" >&2; exit 2 ;;
  esac
done
shift "$((OPTIND - 1))"

_arch="${1:-arm64}"
case "$_arch" in
  arm64|x86_64) ;;
  *) echo "Usage: $0 [-c|-d] [arm64|x86_64]" >&2; exit 2 ;;
esac

prepare_sources "$_download"
configure_build "$_arch" release

helium_build chrome/installer/mac
"$_root_dir/sign_and_package_app.sh"
