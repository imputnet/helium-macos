#!/usr/bin/env bash
set -e

src_dir="$1"
depot_tools_dir="$2"
go_arch="mac-${3/x86_64/amd64}"
go_dir="$src_dir/third_party/dawn/tools/golang/$go_arch"

[ -x "$go_dir/bin/go" ] && exit

go_version=$(sed -n "s/.*'dawn_go_version': '\\([^']*\\)'.*/\\1/p" \
    "$src_dir/third_party/dawn/DEPS" | head -1)
mkdir -p "$go_dir"
printf '%s\n' "infra/3pp/tools/go/$go_arch $go_version" |
    "$depot_tools_dir/cipd" ensure --root "$go_dir" --ensure-file -
