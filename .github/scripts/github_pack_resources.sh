#!/bin/bash -eux

tar --exclude='.git' --exclude='helium-chromium/.git' -c -f - . | zstd -vv -11 -T0 -o build_resources.tar.zst

sha256sum ./build_resources.tar.zst | tee ./build_resources_sums.txt

mkdir -p upload_build_resources
mv build_resources.tar.zst build_resources_sums.txt upload_build_resources/
cp -va ./*.log upload_build_resources/

ls -kahl upload_build_resources/
du -hs upload_build_resources/
