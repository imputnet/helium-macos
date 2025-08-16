#!/bin/bash -eux

_root_dir="$(dirname "$(greadlink -f "$0")")"
_main_repo="$_root_dir/helium-chromium"

_chromium_version=$(cat $_main_repo/chromium_version.txt)
_ungoogled_revision=$(cat $_main_repo/revision.txt)
_package_revision=$(cat $_root_dir/revision.txt)
_helium_version=$(python3 "$_main_repo/utils/helium_version.py" --tree "$_main_repo" --platform-tree "$_root_dir" --print)


_base_hash_name="helium_${_helium_version}"
_x64_hash_name="${_base_hash_name}_x86_64-macos.dmg.hashes.md"
_arm64_hash_name="${_base_hash_name}_arm64-macos.dmg.hashes.md"

_gh_run_href="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

touch ./github_release_note.md
printf '## Helium macOS %s\n' "${_helium_version}" | tee -a ./github_release_note.md

if [ -f $_root_dir/announcements.md ]; then
    printf '### Announcements %s\n\n' | tee -a ./github_release_note.md
    
    _announcement="${_root_dir}/announcements.md"
    cat $_announcement | tee -a ./github_release_note.md

    printf '\n' | tee -a ./github_release_note.md
    printf '### Release Assets Info %s\n\n' | tee -a ./github_release_note.md
fi

cat $_arm64_hash_name | tee -a ./github_release_note.md
printf '\n' | tee -a ./github_release_note.md
cat $_x64_hash_name | tee -a ./github_release_note.md

submodule_commit_at() {
    git ls-tree "$1" helium-chromium | awk '{print $3}'
}

last_tag=$(git describe --tags --abbrev=0)
commit_then=$(submodule_commit_at "$last_tag")
commit_now=$(submodule_commit_at HEAD)

{
  printf 'Changes since last build:\n### helium-macos\n```\n'
  git log --oneline "$last_tag..HEAD"
  printf '```\n\n### helium-chromium\n```\n'
  git -C helium-chromium log --oneline "$commit_then..$commit_now"
  printf '```\n\n---\n\n'
  printf 'See [this GitHub Actions Run](%s) for the [Workflow file](%s/workflow) used '
  printf 'as well as the build logs and artifacts\n' "$_gh_run_href" "$_gh_run_href" 
} | tee -a ./github_release_note.md
