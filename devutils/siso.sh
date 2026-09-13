#!/usr/bin/env bash

source "$_root_dir/devutils/cipd.sh"

___helium_setup_siso() {
    install_cipd_package 'build/siso/${platform}' third_party/siso/cipd --var=siso_version
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
