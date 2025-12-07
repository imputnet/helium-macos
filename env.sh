# The architecture of the running shell
# Also used to determine the build target architecture
_arch="$(/usr/bin/uname -m)"
_rust_target="x86_64-apple-darwin"
if [[ $_arch == "arm64" ]]; then
  _rust_target="aarch64-apple-darwin"
fi

# Some path variables
_root_dir=$(dirname $(greadlink -f $0))
_download_cache="$_root_dir/build/download_cache"
_src_dir="$_root_dir/build/src"
_main_repo="$_root_dir/helium-chromium"
_subs_cache="$_root_dir/build/subs.tar.gz"
_namesubs_cache="$_root_dir/build/namesubs.tar"
_clang_dir="$_src_dir/third_party/llvm-build/Release+Asserts"
