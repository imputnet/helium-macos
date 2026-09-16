#!/usr/bin/env bash

# Shared build steps for local, development, and CI entry points.
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  set -euo pipefail
fi
if [ -z "${_root_dir:-}" ]; then
  _root_dir="$(dirname "$(dirname "$(greadlink -f "${BASH_SOURCE[0]}")")")"
fi

source "$_root_dir/env.sh"
source "$_root_dir/devutils/build_tools.sh"

helium_resources() {
  python3 "$_main_repo/utils/generate_resources.py" "$_main_repo/resources/generate_resources.txt" "$_main_repo/resources"
  python3 "$_main_repo/utils/replace_resources.py" "$_root_dir/resources/platform_resources.txt" "$_root_dir/resources" "$_src_dir"
  python3 "$_main_repo/utils/replace_resources.py" "$_main_repo/resources/helium_resources.txt" "$_main_repo/resources" "$_src_dir"
}

prepare_sources() {
  local arch="$1" download="$2"
  local retrieve_args=(-g)
  if [ "$download" = true ]; then
    retrieve_args=(-d -g)
  fi

  rm -rf "$_src_dir/out"
  mkdir -p "$_download_cache"
  "$_root_dir/retrieve_and_unpack_resource.sh" "${retrieve_args[@]}" "$arch"

  mkdir -p "$_out_dir"
  python3 "$_main_repo/utils/prune_binaries.py" "$_src_dir" "$_main_repo/pruning.list"
  "$_root_dir/retrieve_and_unpack_resource.sh" -t "$arch"

  python3 "$_main_repo/utils/patches.py" apply "$_src_dir" "$_main_repo/patches" "$_root_dir/patches"
  python3 "$_main_repo/utils/domain_substitution.py" apply -r "$_main_repo/domain_regex.list" -f "$_main_repo/domain_substitution.list" "$_src_dir"
  python3 "$_main_repo/utils/name_substitution.py" --sub -t "$_src_dir"
  python3 "$_main_repo/utils/i18n_apply.py" -t "$_src_dir"
  python3 "$_main_repo/utils/helium_version.py" \
    --tree "$_main_repo" --platform-tree "$_root_dir" --chromium-tree "$_src_dir"

  helium_resources
}

write_gn_args() {
  local arch="$1" mode="$2" pgo="$3" args="$_out_dir/args.gn"
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
      echo 'devtools_skip_typecheck = false' >> "$args"
      sed -i '' s/is_official_build/is_component_build/ "$args"
    fi
  fi

  if [ "$pgo" = true ]; then
    echo 'chrome_pgo_phase=2' >> "$args"
  fi
}

configure_build() {
  local arch="$1" ci="$2" pgo="$3"
  if [ "$ci" = true ]; then
    write_gn_args "$arch" ci "$pgo"
  else
    write_gn_args "$arch" release "$pgo"
  fi
  cd "$_src_dir"
  ___helium_install_cipd_deps
  ___helium_configure_siso
  "$_gn_path" gen out/Default --fail-on-unused-args
}

helium_build() {
  cd "$_src_dir"
  local SISO_PATH="$_siso_path"
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
