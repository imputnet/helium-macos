#!/usr/bin/env bash

_root_dir=$(dirname $(greadlink -f $0))

source "$_root_dir/env.sh"
source "$_root_dir/devutils/set_quilt_vars.sh"

___helium_setup_gn() {
    local OUT_FILE="$_src_dir/out/Default/args.gn"
    cat "$_main_repo/flags.gn" "$_root_dir/flags.macos.gn" > "$OUT_FILE"

    if command -v ccache 2>&1 >/dev/null; then
        echo 'cc_wrapper="env CCACHE_SLOPPINESS=time_macros ccache"' >> "$OUT_FILE"
    else
        echo 'warn: ccache is not available' >&2
    fi

    local TARGET_CPU="x64"
    if [[ $_arch == "arm64" ]]; then
        TARGET_CPU=arm64
    fi

    echo 'target_cpu = "'"$TARGET_CPU"'"' >> "$OUT_FILE"
    echo 'use_thin_lto = false' >> "$OUT_FILE"

    sed -i '' s/is_official_build/is_component_build/ "$OUT_FILE"
}

___helium_pull() {
    "$_root_dir/retrieve_and_unpack_resource.sh" -g

    mkdir -p "$_src_dir/out/Default"
    cd "$_src_dir" \
     && git config core.untrackedCache true \
     && git config core.fsmonitor true
}

___helium_pull_thirdparty() {
    mkdir -p "$_src_dir/third_party/llvm-build/Release+Asserts"
    mkdir -p "$_src_dir/third_party/rust-toolchain/bin"
    ln -s "$_src_dir/third_party" "$_root_dir/build/third_party"

    "$_root_dir/retrieve_and_unpack_resource.sh" -p
}

___helium_configure() {
    cd "$_src_dir"
    python3 ./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
    python3 ./tools/rust/build_bindgen.py --rust-target $_rust_target
    ./out/Default/gn gen out/Default --fail-on-unused-args
}

___helium_setup() {
    if [ -d "$_src_dir/out" ]; then
        echo "$_src_dir/out already exists" >&2
        return
    fi

    rm -rf "$_src_dir" && mkdir -p "$_download_cache" "$_src_dir"

    ___helium_pull
    python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
    ___helium_setup_gn
    ___helium_pull_thirdparty

    "$_root_dir/devutils/update_patches.sh" merge
    cd "$_src_dir"
    quilt push -a --refresh

    ___helium_configure
}

___helium_reset() {
    "$_root_dir/devutils/update_patches.sh" unmerge || true
    (
        mv "$_src_dir" "${_src_dir}x" && \
        rm -rf "${_src_dir}x"
    ) &
}

___helium_build() {
    cd "$_src_dir" && ninja -C out/Default chrome chromedriver
}

___helium_pull() {
    cd "$_src_dir" && quilt pop -a
    "$_root_dir/devutils/update_patches.sh" unmerge || true

    for dir in "$_root_dir" "$_main_repo"; do
        git -C "$dir" stash \
        && git -C "$dir" fetch \
        && git -C "$dir" rebase origin/main \
        && git -C "$dir" stash pop
    done

    "$_root_dir/devutils/update_patches.sh" merge
    cd "$_src_dir" && quilt push -a --refresh
}

__helium_menu() {
    set -e
    case $1 in
        s|setup) ___helium_setup;;
        b|build) ___helium_build;;
        p|pull) ___helium_pull;;
        reset) ___helium_reset;;
        *)
            echo "usage: $0 (setup | build | pack | reset)" >&2
            echo "\tsetup - sets up the dev environment for the first itme" >&2
            echo "\tbuild - prepares a development build binary" >&2
            echo "\tpull - undoes all patches, pulls, redoes all patches" >&2
            echo "\treset - nukes everything" >&2
    esac
}

he() {
    (__helium_menu)
}

if ! (return 0 2>/dev/null); then
    printf "usage:\n\t$ source dev.sh\n\t$ he\n" 2>&1
    exit 1
else
    PS1="🎈 $PS1"
fi
