#!/usr/bin/env bash
set -e

_src_dir="$1"
source "$(dirname "$0")/cipd.sh"

go_platform="mac-$(/usr/bin/uname -m)"
go_platform="${go_platform/x86_64/amd64}"
install_cipd_package 'infra/3pp/tools/go/${platform}' \
    "third_party/dawn/tools/golang/$go_platform" --var=dawn_go_version third_party/dawn/DEPS
