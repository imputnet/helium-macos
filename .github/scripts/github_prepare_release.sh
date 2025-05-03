#!/bin/bash -eux

_root_dir=$(dirname $(greadlink -f $0))
_main_repo="$_root_dir/helium-chromium"

_chromium_version=$(cat $_main_repo/chromium_version.txt)
_ungoogled_revision=$(cat $_main_repo/revision.txt)
_package_revision=$(cat $_main_repo/revision.txt)

_helium_version=$(python3 "$_main_repo/utils/helium_version.py" --tree "$_main_repo" --platform-tree "$_root_dir" --print)

_file_name_base="helium_${_helium_version}"
_x64_file_name="${_file_name_base}_x86_64-macos.dmg"
_arm64_file_name="${_file_name_base}_arm64-macos.dmg"

_release_tag_version="${_helium_version}-${_chromium_version}"
_release_name="${_helium_version}"

echo "x64_file_name=$_x64_file_name" >> $GITHUB_OUTPUT
echo "arm64_file_name=$_arm64_file_name" >> $GITHUB_OUTPUT
echo "release_tag_version=$_release_tag_version" >> $GITHUB_OUTPUT
echo "release_name=$_release_name" >> $GITHUB_OUTPUT
