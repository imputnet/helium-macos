# Loads helium-chromium's quilt settings and points them at the merged
# platform patch series. Source this, don't run it.
_quilt_root=$(dirname "$(dirname "$(greadlink -f "${BASH_SOURCE[0]:-${(%):-%x}}")")")

source "$_quilt_root/helium-chromium/devutils/set_quilt_vars.sh"
export QUILT_PATCHES="$_quilt_root/patches"
export QUILT_SERIES="$QUILT_PATCHES/series.merged"

unset _quilt_root
