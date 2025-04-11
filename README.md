# helium-macos

macOS packaging for [helium-chromium](//github.com/imputnet/helium-chromium).

Slightly edited version of [ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos).

## Building

### Software requirements

* macOS 10.15+
* Xcode 12
* Homebrew
* Perl (for creating a `.dmg` package)
* Node.js

### Setting up the build environment

1. Install Python 3 via Homebrew: `brew install python@3`
2. Install `httplib2` via `pip3`: `pip3 install httplib2`, note that you might need to use `--break-system-packages` if you don't want to use a dedicated Python environment for building Ungoogled-Chromium.
3. Install LLVM via Homebrew: `brew install llvm`, and set `LDFLAGS` and `CPPFLAGS` environment variables according to the Homebrew prompt.
4. Install Ninja via Homebrew: `brew install ninja`
5. Install GNU coreutils and readline via Homebrew: `brew install coreutils readline`
6. Install the data compression tools xz and zlib via Homebrew: `brew install xz zlib`
7. Unlink binutils to use the one provided with Xcode: `brew unlink binutils`
8. Install Node.js via Homebrew: `brew install node`
9. Restart your terminal.

**NOTE**: If you are building for x86_64 Mac from an Apple Silicon (arm64) Mac, you might need to install Rosetta 2 and these tools from x86_64 Homebrew, as well as setting `PATH` variables to use the x86_64 tools.

### Build

First, ensure the Xcode application is open.

If you want to notarize the build, you need to have an Apple Developer ID and a valid Apple Developer Program membership. You also need to set the following environment variables:

- `MACOS_CERTIFICATE_NAME`: The Full Name of the Developer ID Certificate you created (type `G2 Sub-CA (Xcode 11.4.1 or later)`) in Apple Developer portal, e.g.: Developer ID Application: Your Name (K1234567)
- `PROD_MACOS_NOTARIZATION_APPLE_ID`: The email you used to register your Apple Account and Apple Developer Program
- `PROD_MACOS_NOTARIZATION_TEAM_ID`: Your Apple Developer Team ID, which can be found in the Apple Developer membership page
- `PROD_MACOS_NOTARIZATION_PWD`: An app-specific password generated in the Apple ID account settings

If you don't have an Apple Developer ID to sign the build (or you don't want to sign it), you can simply not specify MACOS_CERTIFICATE_NAME.

```sh
git clone --recurse-submodules https://github.com/imputnet/helium-macos.git
cd helium-macos
```

to switch to the desired release or development branch.

Finally, run the following (if you are building for the same architecture as your Mac, i.e. x86_64 for Intel Macs or arm64 for Apple Silicon Macs, or if you are building for arm64 on an Intel Mac and you set the appropriate build flag):

```sh
./build.sh
```

or, if you want to build for x86_64 on an Apple Silicon Mac:

```sh
./build.sh x86_64
```

Once it's complete, a `.dmg` should appear in `build/`.

**NOTE**: If the build fails, you must take additional steps before re-running the build:

* If the build fails while downloading the Chromium source code, it can be fixed by removing `build/downloads_cache` and re-running the build instructions.
* If the build fails at any other point after downloading, it can be fixed by removing `build/src` and re-running the build instructions.

## Developer info

### Updating

1. Start the process and set the environment variables

    ```sh
    ./devutils/update_patches.sh merge
    source devutils/set_quilt_vars.sh
    ```

2. Setup Chromium source

    ```sh
    mkdir -p build/{src,download_cache}
    ./retrieve_and_unpack_resource.sh -g arm64  # For Apple Silicon Macs
    ./retrieve_and_unpack_resource.sh -p arm64  # For Apple Silicon Macs
    ./retrieve_and_unpack_resource.sh -g x86_64  # For Intel Chip Macs
    ./retrieve_and_unpack_resource.sh -p x86_64  # For Intel Chip Macs
    ```

3. Update Rust toolchain (if necessary)
    1. Check the `RUST_VERSION` constant in file `src/tools/rust/update_rust.py` in build root.
        * As an example, the revision as of writing this guide is `340bb19fea20fd5f9357bbfac542fad84fc7ea2b`.
    2. Get date for nightly Rust build from Rust's GitHub repository.
        * The page URL for our example is `https://github.com/rust-lang/rust/commit/340bb19fea20fd5f9357bbfac542fad84fc7ea2b`
            1. In this case, the corresponding nightly build date is `2024-02-14`.
            2. Adapt the version number in `downloads-arm64.ini` and `downloads-x86_64.ini` accordingly.
    3. Get the information of the latest nightly build and adapt configurations accordingly.
       1. Download the latest nightly build from the Rust website.
            * For our example, the download URL for Apple Silicon Macs is `https://static.rust-lang.org/dist/2024-02-14/rust-nightly-aarch64-apple-darwin.tar.gz`
            * For our example, the download URL for Intel Chip Macs is `https://static.rust-lang.org/dist/2024-02-14/rust-nightly-x86_64-apple-darwin.tar.gz`
       2. Extract the archive.
       3. Execute `rustc/bin/rustc -V` in the extracted directory to get Rust version string.
            * For our example, the version string is `rustc 1.78.0-nightly (a84bb95a1 2024-02-13)`.
       4. Adapt the content of `retrieve_and_unpack_resource.sh` and `patches/ungoogled-chromium/macos/fix-build-with-rust.patch` accordingly.
4. Switch to src directory

    ```sh
    cd build/src
    ```

5. Use `quilt` to refresh all patches: `quilt push -a --refresh`
   * If an error occurs, go to the next step. Otherwise, skip to Step 7.
6. Use `quilt` to fix the broken patch:
    1. Run `quilt push -f`
    2. Edit the broken files as necessary by adding (`quilt edit ...` or `quilt add ...`) or removing (`quilt remove ...`) files as necessary
        * When removing large chunks of code, remove each line instead of using language features to hide or remove the code. This makes the patches less susceptible to breakages when using quilt's refresh command (e.g. quilt refresh updates the line numbers based on the patch context, so it's possible for new but desirable code in the middle of the block comment to be excluded.). It also helps with readability when someone wants to see the changes made based on the patch alone.
    3. Refresh the patch: `quilt refresh`
    4. Go back to Step 5.
7. Run `../../helium-chromium/devutils/validate_config.py`
8. Run `quilt pop -a`
9. Validate that patches are applied correctly

    ```sh
    cd ../..
    ./helium-chromium/devutils/validate_patches.py -l build/src -s patches/series.merged
    ```

10. Remove all patches introduced by ungoogled-chromium: `./devutils/update_patches.sh unmerge`
11. Ensure patches/series is formatted correctly, e.g. blank lines
12. Sanity checking for consistency in series file: `./devutils/check_patch_files.sh`
13. Use git to add changes and commit

## License

All code, patches, modified portions of imported code or patches, and
any other content that is unique to Helium and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](https://github.com/ungoogled-software/ungoogled-chromium-macos/blob/630a05a30c8b955b6d33777aeebff2c0bce7beaa/LICENSE)).
