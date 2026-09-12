#!/usr/bin/env bash

install_cipd_package() {
    local package="$1"
    local destination="${_src_dir}/$2"
    local version_selector="$3"
    local deps_file="${_src_dir}/${4:-DEPS}"
    local version
    version="$(python3 "${_src_dir}/third_party/depot_tools/gclient.py" getdep \
        "$version_selector" --deps-file="$deps_file")" || return
    mkdir -p "$destination" || return
    printf '%s %s\n' "$package" "$version" |
        "${_src_dir}/third_party/depot_tools/cipd" ensure \
            -ensure-file - -root "$destination"
}
