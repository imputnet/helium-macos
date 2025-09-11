#!/bin/bash -eux

_root_dir="$(dirname "$(greadlink -f "$0")")"

# For packaging
_chromium_version=$(cat "$_root_dir"/helium-chromium/chromium_version.txt)
_ungoogled_revision=$(cat "$_root_dir"/helium-chromium/revision.txt)
_package_revision=$(cat "$_root_dir"/revision.txt)

# Fix issue where macOS requests permission for incoming network connections
# See https://github.com/ungoogled-software/ungoogled-chromium-macos/issues/17
xattr -cs out/Default/Helium.app

if ! [ -z "${MACOS_CERTIFICATE_NAME-}" ]; then
  APP_ENTITLEMENTS="$_root_dir/entitlements/app-entitlements.plist"

  if ! [ -z "${PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH-}" ]; then
    APP_ENTITLEMENTS=$(mktemp)
    sed 's/${CHROMIUM_TEAM_ID}/'"$PROD_MACOS_NOTARIZATION_TEAM_ID/" \
      "$_root_dir/entitlements/app-entitlements-all.plist" > "$APP_ENTITLEMENTS"

    cp "$PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH" "out/Default/Helium.app/Contents/embedded.provisionprofile"
  fi

  if [ -d ./out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Frameworks/Sparkle.framework ]; then
    codesign --sign "$MACOS_CERTIFICATE_NAME" --force --deep --timestamp --options restrict,library,runtime,kill ./out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Frameworks/Sparkle.framework
  fi

  # Sign the binary
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier chrome_crashpad_handler --options=restrict,library,runtime,kill out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/chrome_crashpad_handler
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium.helper --options restrict,library,runtime,kill --entitlements $_root_dir/entitlements/helper-entitlements.plist out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/Helium\ Helper.app
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium.helper.renderer --options restrict,kill,runtime --entitlements $_root_dir/entitlements/helper-renderer-entitlements.plist out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/Helium\ Helper\ \(Renderer\).app
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium.helper --options restrict,kill,runtime --entitlements $_root_dir/entitlements/helper-gpu-entitlements.plist out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/Helium\ Helper\ \(GPU\).app
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium.helper.plugin --options restrict,kill,runtime --entitlements $_root_dir/entitlements/helper-plugin-entitlements.plist out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/Helium\ Helper\ \(Plugin\).app
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium.framework.AlertNotificationService --options restrict,library,runtime,kill out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/Helium\ Helper\ \(Alerts\).app
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier app_mode_loader --options restrict,library,runtime,kill out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/app_mode_loader
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier web_app_shortcut_copier --options restrict,library,runtime,kill out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Helpers/web_app_shortcut_copier
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier libEGL out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Libraries/libEGL.dylib
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier libGLESv2 out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Libraries/libGLESv2.dylib
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier libvk_swiftshader out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework/Libraries/libvk_swiftshader.dylib
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium.framework --entitlements $_root_dir/entitlements/helper-entitlements.plist out/Default/Helium.app/Contents/Frameworks/Helium\ Framework.framework
  codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium --options restrict,library,runtime,kill --entitlements $APP_ENTITLEMENTS --requirements '=designated => identifier "net.imput.helium" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = '"$PROD_MACOS_NOTARIZATION_TEAM_ID" out/Default/Helium.app

  # For debugging component builds:
  # codesign --sign "$MACOS_CERTIFICATE_NAME" --force --timestamp --identifier net.imput.helium --options restrict,library,runtime,kill --entitlements $APP_ENTITLEMENTS --requirements '=designated => identifier "net.imput.helium" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = '"$PROD_MACOS_NOTARIZATION_TEAM_ID" out/Default/*.dylib

  # Verify the binary signature
  codesign --verify --deep --verbose=4 out/Default/Helium.app

  # Pepare app notarization
  ditto -c -k --keepParent "out/Default/Helium.app" "$TMPDIR/notarize.zip"

  # Notarize the app
  CUSTOM_KEYCHAIN_ARG=""

  if ! [ -z "${CI-}" ]; then
    CUSTOM_KEYCHAIN_ARG="--keychain=~/Library/Keychains/build.keychain-db"
  fi

  xcrun notarytool \
    store-credentials "notarytool-profile" \
    --apple-id "$PROD_MACOS_NOTARIZATION_APPLE_ID" \
    --team-id "$PROD_MACOS_NOTARIZATION_TEAM_ID" \
    --password "$PROD_MACOS_NOTARIZATION_PWD" \
    $CUSTOM_KEYCHAIN_ARG

  xcrun notarytool \
    submit "$TMPDIR/notarize.zip" \
    --keychain-profile "notarytool-profile" \
    --wait \
    $CUSTOM_KEYCHAIN_ARG

  xcrun stapler \
    staple "out/Default/Helium.app"

  rm "$TMPDIR/notarize.zip"

  # Clean up entitlements if needed
  if ! [ -z "${PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH-}" ]; then
    rm -f "$APP_ENTITLEMENTS"
  fi
else
  echo "warn: MACOS_CERTIFICATE_NAME is missing; skipping notarization" >&2
  codesign --force --deep --sign - out/Default/Helium.app
fi

if [ -z "${OUT_DMG_PATH:-}" ]; then
  OUT_DMG_PATH="$_root_dir/build/helium_${_chromium_version}-${_ungoogled_revision}.${_package_revision}_macos.dmg"
fi

# Package the app
if command -v appdmg 2>&1 >/dev/null || [ -n "${NEEDS_APPDMG:-}" ]; then
  ln -sf "$_root_dir/resources/dmg.json" out/Default
  appdmg out/Default/dmg.json "$OUT_DMG_PATH"
else
  echo "no appdmg, falling back to stock .dmg" >&2

  chrome/installer/mac/pkg-dmg \
    --sourcefile --source out/Default/Helium.app \
    --target "$OUT_DMG_PATH" \
    --volname Helium --symlink /Applications:/Applications \
    --format ULMO --verbosity 2
fi

if ! [ -z "${MACOS_CERTIFICATE_NAME-}" ]; then
  codesign \
    --sign "$MACOS_CERTIFICATE_NAME" \
    --identifier net.imput.helium --force \
    "$OUT_DMG_PATH"
fi
