#!/bin/bash
set -exo pipefail

source dev.sh

export QUILT_PATCHES="$PWD/patches"
export QUILT_SERIES="series.merged"

_check="${1:-sanity}"
_source_archive="$_root_dir/build/chromium-source.tar"

mkdir -p "$_src_dir" "$_download_cache"
if [ -f "$_source_archive" ]; then
    tar -xf "$_source_archive" -C "$_src_dir"
else
    "$_root_dir/retrieve_and_unpack_resource.sh" -d -g || \
        "$_root_dir/retrieve_and_unpack_resource.sh" -g
    python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"

    # Keep the cached archive unpatched, without clone history or staging files.
    tar -cf "$_source_archive" --exclude=.git --exclude=./uc_staging -C "$_src_dir" .
fi

if [ "$_check" = "sanity" ]; then
    mkdir -p "$_out_dir"
    ___helium_toolchain
    ___helium_setup_gn
fi

he resources
python3 "$_main_repo/utils/helium_version.py" \
    --tree "$_main_repo" --platform-tree "$_root_dir" --chromium-tree "$_src_dir"
he merge
he push | tee setup.log

if [ "$_check" = "substitution" ]; then
    python3 "$_main_repo/utils/name_substitution.py" --sub -t "$_src_dir"
    python3 "$_main_repo/utils/domain_substitution.py" apply \
        -r "$_main_repo/domain_regex.list" \
        -f "$_main_repo/domain_substitution.list" "$_src_dir"

    grep -q Helium "$_src_dir/components/omnibox_strings.grdp"
    exit 0
fi

if grep -q 'offset .* lines' setup.log; then
    grep -A20 -B20 'offset .* lines' setup.log >&2
    exit 1
fi

he configure

cd "$_src_dir"
_status_code=0
SISO_PATH="$_siso_path" timeout 30 python3 "$_depot_tools_dir/autoninja.py" -C out/Default chrome chromedriver || _status_code=$?
test "$_status_code" -eq 124
