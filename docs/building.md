# Building and developing Helium

### Navigation
- [Official (non-development) build](#official-non-development-build)
- [Development build and environment](#development-build-and-environment)
    - [Basics](#basics)
    - [Creating a new patch](#creating-a-new-patch)
    - [Updating for a new Chromium release](#updating-for-a-new-chromium-release)

### Software requirements

* macOS 12+
* Xcode 26
* Homebrew
* Perl (for creating a `.dmg` package)
* Node.js

### Build dependencies

1. Install Python 3 via Homebrew: `brew install python@3.13`
2. Install Python dependencies via `pip3`: `pip3 install httplib2==0.22.0 requests pillow`
    * Note that you might need to use `--break-system-packages` if you don't want to use a
      dedicated Python environment for building Helium.
3. Install Metal toolchain: `xcodebuild -downloadComponent MetalToolchain`
4. Install Ninja via Homebrew: `brew install ninja`
5. Install GNU coreutils and readline via Homebrew: `brew install coreutils readline`
6. Unlink binutils to use the one provided with Xcode: `brew unlink binutils`
7. Install Node.js via Homebrew: `brew install node`
8. Restart your terminal.

## Official (non-development) build

First, ensure the Xcode application is open.

If you want to notarize the build, you need to have an Apple Developer ID and a valid Apple Developer Program membership. You also need to set the following environment variables:

- `MACOS_CERTIFICATE_NAME`: The Full Name of the Developer ID Certificate you created (type `G2 Sub-CA (Xcode 11.4.1 or later)`) in Apple Developer portal, e.g.: Developer ID Application: Your Name (K1234567)
- `PROD_MACOS_NOTARIZATION_APPLE_ID`: The email you used to register your Apple Account and Apple Developer Program
- `PROD_MACOS_NOTARIZATION_TEAM_ID`: Your Apple Developer Team ID, which can be found in the Apple Developer membership page
- `PROD_MACOS_NOTARIZATION_PWD`: An app-specific password generated in the Apple ID account settings
- `PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH`: Path to the provisioning profile that allows you to use entitlements which need to be specifically approved by Apple (`com.apple.developer.web-browser.public-key-credential`, `com.apple.developer.associated-domains.applinks.read-write`).

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

## Development build and environment

Make sure your system meets the [requirements](#software-requirements)
and that you've installed all [dependencies](#build-dependencies).

On top of basic dependencies, you'll need quilt to create/update patches:
```sh
brew install quilt
```

### Basics

1. Load the dev util script:
    ```sh
    source dev.sh
    ```

2. Setup the dev environment fully for the first time:
    ```sh
    he setup
    ```

3. Build your first development binary:
    ```sh
    he build
    ```

4. Run the development build with a dedicated data dir:
    ```sh
    he run
    ```

5. Done! You have your own home-grown Helium ready for tinkering.

### Creating a new patch

1. Go to the build dir:
    ```sh
    cd build/src
    ```

2. Create a new patch with quilt:
    ```sh
    quilt new <path_to_patch>
    ```

3. Add files to this patch:
    ```sh
    quilt add <path_to_file1> <path_to_file2>
    ```
    * Note: path here is relative to `build/src`

4. Modify files, test them by building and running Helium.

5. When you're done, refresh the patch:
    ```sh
    quilt refresh
    ```

6. Unmerge the patch series:
    ```sh
    he unmerge
    ```

7. Commit the patch & series change to a new branch and make a PR!

#### Dev util help menu
To see all commands available in `dev.sh`, just run `he`.

#### quilt manual
Confused about quilt? Run ```man quilt``` to read more about its functionality.

### Updating for a new Chromium release
1. Load the dev util script:
    ```sh
    source dev.sh
    ```

2. Download sources, set up GN, and prepare third-party dependencies:
    ```sh
    he presetup
    ```

3. Update Rust toolchain (if necessary)
    1. Check the `RUST_REVISION` constant in file `src/tools/rust/update_rust.py` in build root.
        * As an example, the revision as of writing this guide is `22be76b7e259f27bf3e55eb931f354cd8b69d55f`.
    2. Get date for nightly Rust build from Rust's GitHub repository.
        * The page URL for our example is `https://github.com/rust-lang/rust/commit/22be76b7e259f27bf3e55eb931f354cd8b69d55f`
            1. In this case, the corresponding nightly build date is `2025-06-23`.
            2. Adapt the version number in `downloads-{arm64,x86-64}{,-rustlib}.ini` accordingly.
    3. Get the information of the latest nightly build and adapt configurations accordingly.
       1. Download the latest nightly build from the Rust website.
            * For our example, the download URL for Apple Silicon Macs is `https://static.rust-lang.org/dist/2025-06-23/rust-nightly-aarch64-apple-darwin.tar.gz`
            * For our example, the download URL for Intel Chip Macs is `https://static.rust-lang.org/dist/2025-06-23/rust-nightly-x86_64-apple-darwin.tar.gz`
       2. Extract the archive.
       3. Execute `rustc/bin/rustc -V` in the extracted directory to get Rust version string.
            * For our example, the version string is `rustc 1.89.0-nightly (be19eda0d 2025-06-22)`.
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

7. After all patches are fixed, run `he version && he configure` to finish build env setup.
8. Build and run Helium to verify that everything functions as intended: `he build && he run`
9. Run `he validate config` and resolve the error if it occurs.
10. Run `he pop` to pop all applied patches.
11. Validate that patches are applied correctly: `he validate config`
12. Unmerge main and platform patches: `he unmerge`
13. Ensure that patches and series are formatted correctly, e.g. no blank lines.
14. Check the consistency of the series file: `he validate series`
15. Use git to add changes and commit. Refer to recent commit history for an appropriate commit comment.
