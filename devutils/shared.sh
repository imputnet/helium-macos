#!/usr/bin/env bash

# Shared build steps for local, development, and CI entry points.
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
fi
if [ -z "${_root_dir:-}" ]; then
  _root_dir="$(dirname "$(dirname "$(greadlink -f "${BASH_SOURCE[0]}")")")"
fi

source "$_root_dir/env.sh"

helium_resources() {
  python3 "$_main_repo/utils/generate_resources.py" "$_main_repo/resources/generate_resources.txt" "$_main_repo/resources"
  python3 "$_main_repo/utils/replace_resources.py" "$_root_dir/resources/platform_resources.txt" "$_root_dir/resources" "$_src_dir"
  python3 "$_main_repo/utils/replace_resources.py" "$_main_repo/resources/helium_resources.txt" "$_main_repo/resources" "$_src_dir"
}

fetch_sources() {
  local download="${1:-true}" host_arch
  local downloads=("$_root_dir/downloads.ini" "$_main_repo/deps.ini")

  mkdir -p "$_download_cache" || return
  if [ "$download" = false ]; then
    python3 "$_main_repo/utils/clone.py" -o "$_src_dir" || return
  else
    # Select host tools; each overlay supports both target architectures.
    case "$(uname -m)" in
      arm64) host_arch=arm64 ;;
      x86_64) host_arch=x64 ;;
      *) echo "Unsupported macOS host architecture: $(uname -m)" >&2; return 1 ;;
    esac
    downloads=("$_main_repo/downloads.ini" "$_root_dir/downloads.$host_arch.ini" "${downloads[@]}")
  fi

  python3 "$_main_repo/utils/downloads.py" retrieve -i "${downloads[@]}" -c "$_download_cache" || return
  python3 "$_main_repo/utils/downloads.py" unpack -i "${downloads[@]}" -c "$_download_cache" "$_src_dir" || return

  # The macOS remote wrapper uses a separate Linux compiler on workers.
  if [ -n "${SISO_REAPI_ADDRESS:-}" ]; then
    python3 "$_src_dir/tools/clang/scripts/update.py" \
      --host-os=linux \
      --output-dir="$_src_dir/third_party/llvm-build/Release+Asserts_linux"
  fi
}

prepare_sources() {
  rm -rf "$_src_dir/out"
  fetch_sources "${1:-true}" || return

  mkdir -p "$_out_dir"
  python3 "$_main_repo/utils/prune_binaries.py" --keep-build-dependencies "$_src_dir" "$_main_repo/pruning.list"

  python3 "$_main_repo/utils/patches.py" apply "$_src_dir" "$_main_repo/patches" "$_root_dir/patches"
  python3 "$_main_repo/utils/domain_substitution.py" apply -r "$_main_repo/domain_regex.list" -f "$_main_repo/domain_substitution.list" "$_src_dir"
  python3 "$_main_repo/utils/name_substitution.py" --sub -t "$_src_dir"
  python3 "$_main_repo/utils/i18n_apply.py" -t "$_src_dir"
  python3 "$_main_repo/utils/helium_version.py" \
    --tree "$_main_repo" --platform-tree "$_root_dir" --chromium-tree "$_src_dir"

  helium_resources
}

write_gn_args() {
  local arch="$1" mode="$2" args="$_out_dir/args.gn"
  local target_cpu=arm64
  if [ "$arch" = x86_64 ]; then
    target_cpu=x64
  fi

  mkdir -p "$_out_dir"
  cat "$_main_repo/flags.gn" "$_root_dir/flags.macos.gn" > "$args"
  printf 'target_cpu = "%s"\n' "$target_cpu" >> "$args"

  if [ "$mode" = ci ]; then
    echo 'cc_wrapper="sccache"' >> "$args"
    if [ -n "${PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_B64:-}" ]; then
      echo 'include_branded_entitlements=true' >> "$args"
    fi
    if [ -n "${PROD_MACOS_SPARKLE_ED_PUB_KEY:-}" ]; then
      echo 'enable_sparkle=true' >> "$args"
      printf 'sparkle_ed_key="%s"\n' "$PROD_MACOS_SPARKLE_ED_PUB_KEY" >> "$args"
    fi
    echo 'symbol_level=1' >> "$args"
  else
    if [ "$mode" = dev ] && [ -n "${SISO_REAPI_ADDRESS:-}" ]; then
      echo 'use_remoteexec = true' >> "$args"
    elif command -v sccache >/dev/null 2>&1; then
      echo 'cc_wrapper="sccache"' >> "$args"
    elif command -v ccache >/dev/null 2>&1; then
      echo 'cc_wrapper="env CCACHE_COMPILERCHECK=content CCACHE_SLOPPINESS=time_macros ccache"' >> "$args"
    else
      echo 'warn: sccache or ccache is not available' >&2
    fi

    if [ "$mode" = release ] && [ -n "${MACOS_CERTIFICATE_NAME:-}" ] && [ -n "${PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH:-}" ]; then
      echo 'include_branded_entitlements=true' >> "$args"
    fi
    if [ "$mode" = dev ]; then
      sed -i '' s/is_official_build/is_component_build/ "$args"
    fi
  fi

  if [ "$mode" != dev ]; then
    echo 'chrome_pgo_phase=2' >> "$args"
  fi
}

configure_siso() {
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

gn_gen() {
  cd "$_src_dir"
  configure_siso
  "$_gn_path" gen "$_out_dir" --fail-on-unused-args "$@"
}

configure_build() {
  write_gn_args "$1" "$2"
  gn_gen
}

helium_build() {
  cd "$_src_dir"
  local SISO_PATH="${SISO_PATH:-$_siso_path}"
  export SISO_PATH
  local -a command=(python3 "$_depot_tools_dir/autoninja.py" -C "$_out_dir" chrome chromedriver)
  if [ "${_helium_exec_build:-}" = true ]; then
    exec "${command[@]}" "$@"
  fi
  "${command[@]}" "$@"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  if [ "${1:-}" != build ]; then
    echo "Usage: $0 build [options and targets]" >&2
    exit 2
  fi
  shift
  _helium_exec_build=true
  helium_build "$@"
fi
