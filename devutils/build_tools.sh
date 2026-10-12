#!/usr/bin/env bash

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
