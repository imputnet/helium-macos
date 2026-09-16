#!/usr/bin/env bash

___helium_install_cipd_deps() {
    local -a args=("$_src_dir")
    if [ -n "${SISO_REAPI_ADDRESS:-}" ]; then
        args+=(--remote-exec)
    fi

    export CIPD_CACHE_DIR="$_download_cache/cipd"
    mkdir -p "$CIPD_CACHE_DIR"
    python3 "$_main_repo/utils/install_cipd_deps.py" "${args[@]}"
}

___helium_configure_siso() {
    local backend=""
    if [ -n "${SISO_REAPI_ADDRESS:-}" ]; then
        export SISO_REAPI_INSTANCE="${SISO_REAPI_INSTANCE:-main}"
        backend=nativelink.star
    fi

    python3 "$_src_dir/build/config/siso/configure_siso.py" \
        --rbe_instance=projects/rbe-chrome-untrusted/instances/default_instance \
        --reapi_address="${SISO_REAPI_ADDRESS:-}" \
        --reapi_instance="${SISO_REAPI_INSTANCE:-}" \
        --reapi_backend_config_path="$backend"
}
