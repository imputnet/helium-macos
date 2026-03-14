# Building and developing Helium

### Navigation
- [Official (non-development) build](#official-non-development-build)
- [Development build and environment](#development-build-and-environment)
    - [Basics](#basics)
    - [Creating a new patch](#creating-a-new-patch)
    - [Updating for a new Chromium release](#updating-for-a-new-chromium-release)
- [Passkeys on macOS](passkeys.md)

### Software requirements

* macOS 12+
* Xcode 26
* Homebrew
* Perl (for creating a `.dmg` package)

### Build dependencies

1. Install Python 3 via Homebrew: `brew install python@3.13`
1. Install Python dependencies via `pip3`: `pip3 install httplib2==0.22.0 requests pillow`
    * Note that you might need to use `--break-system-packages` if you don't want to use a
      dedicated Python environment for building Helium.
1. Install Metal toolchain: `xcodebuild -downloadComponent MetalToolchain`
1. Install Ninja via Homebrew: `brew install ninja`
1. Install GNU coreutils and readline via Homebrew: `brew install coreutils readline`
1. Unlink binutils to use the one provided with Xcode: `brew unlink binutils`
1. Restart your terminal.

## Official (non-development) build

First, ensure the Xcode application is open.

If you want to notarize the build, you need to have an Apple Developer ID and a valid Apple Developer Program membership. You also need to set the following environment variables:

- `MACOS_CERTIFICATE_NAME`: The Full Name of the Developer ID Certificate you created (type `G2 Sub-CA (Xcode 11.4.1 or later)`) in Apple Developer portal, e.g.: Developer ID Application: Your Name (K1234567)
- `PROD_MACOS_NOTARIZATION_APPLE_ID`: The email you used to register your Apple Account and Apple Developer Program
- `PROD_MACOS_NOTARIZATION_TEAM_ID`: Your Apple Developer Team ID, which can be found in the Apple Developer membership page
- `PROD_MACOS_NOTARIZATION_PWD`: An app-specific password generated in the Apple ID account settings
- `PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH`: Path to the provisioning profile that allows you to use entitlements which need to be specifically approved by Apple (`com.apple.developer.web-browser.public-key-credential`, `com.apple.developer.associated-domains.applinks.read-write`).

For passkey-specific signing behavior and runtime troubleshooting, see
[`docs/passkeys.md`](passkeys.md).

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

1. Download sources, set up GN, and prepare third-party dependencies:
    ```sh
    he presetup
    ```

1. Switch to src directory
    ```sh
    cd build/src
    ```

1. Use `quilt` to refresh all patches: `quilt push -a --refresh`
   * If an error occurs, go to the next step. Otherwise, skip to Step 7.

1. Use `quilt` to fix the broken patch:
    1. Run `quilt push -f`
    2. Edit the broken files as necessary by adding (`quilt edit ...` or `quilt add ...`) or removing (`quilt remove ...`) files as necessary
        * When removing large chunks of code, remove each line instead of using language features to hide or remove the code. This makes the patches less susceptible to breakages when using quilt's refresh command (e.g. quilt refresh updates the line numbers based on the patch context, so it's possible for new but desirable code in the middle of the block comment to be excluded.). It also helps with readability when someone wants to see the changes made based on the patch alone.
    3. Refresh the patch: `quilt refresh`
    4. Go back to Step 5.

1. After all patches are fixed, run `he version && he configure` to finish build env setup.
1. Build and run Helium to verify that everything functions as intended: `he build && he run`
1. Run `he validate config` and resolve the error if it occurs.
1. Run `he pop` to pop all applied patches.
1. Validate that patches are applied correctly: `he validate config`
1. Unmerge main and platform patches: `he unmerge`
1. Ensure that patches and series are formatted correctly, e.g. no blank lines.
1. Check the consistency of the series file: `he validate series`
1. Use git to add changes and commit. Refer to recent commit history for an appropriate commit comment.
