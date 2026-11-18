{
  lib,
  mkShellNoCC,
  writeShellApplication,
  writeShellScriptBin,
  python313,
  coreutils-prefixed,
  gnused,
  q,
  wget,
  zstd,
  sccache,
  xcodes,
  aria2,
}:

let
  # matches .github/scripts/github_prepare_xcode.sh
  defaultXcodeVersion = "26.5";
  minXcodeMajor = 26;

  python = python313.withPackages (
    ps: with ps; [
      requests
      pillow
      httplib2
      six
      unidiff
      schema
    ]
  );

  # scripts call gnu tools as g* for non-nix (homebrew) setups
  gsed = writeShellScriptBin "gsed" ''exec ${gnused}/bin/sed "$@"'';

  resolveXcode = ''
    xcode="''${HELIUM_XCODE:-$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p 2>/dev/null || true)}"
    case "$xcode" in
      *.app) xcode="$xcode/Contents/Developer" ;;
    esac
    xcode_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$xcode/../Info.plist" 2>/dev/null || true)"
    xcode_ok=
    if [ -n "$xcode_version" ] && [ "''${xcode_version%%.*}" -ge ${toString minXcodeMajor} ]; then
      xcode_ok=1
    fi
  '';

  xcodeSetup = writeShellApplication {
    name = "helium-xcode-setup";
    runtimeInputs = [
      xcodes
      aria2
    ];
    text = ''
      version="''${1:-${defaultXcodeVersion}}"
      ${resolveXcode}

      if [ $# -gt 0 ] || [ -z "$xcode_ok" ]; then
        echo "==> installing Xcode $version via xcodes (Apple ID login required)"
        xcodes install "$version" --select --experimental-unxip
        xcode="$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p)"
        if [ -n "''${HELIUM_XCODE:-}" ]; then
          echo "==> note: HELIUM_XCODE is set, unset it to use the new Xcode" >&2
        fi
      fi
      export DEVELOPER_DIR="$xcode"
      echo "==> using $DEVELOPER_DIR"

      echo "==> accepting license and running first launch (sudo)"
      sudo env DEVELOPER_DIR="$DEVELOPER_DIR" /usr/bin/xcodebuild -license accept
      sudo env DEVELOPER_DIR="$DEVELOPER_DIR" /usr/bin/xcodebuild -runFirstLaunch

      echo "==> installing Metal toolchain"
      /usr/bin/xcodebuild -downloadComponent MetalToolchain

      echo "==> done, re-enter the dev shell to pick up changes"
    '';
  };
in
mkShellNoCC {
  name = "helium-macos";

  packages = [
    python
    coreutils-prefixed
    gsed
    q
    wget
    zstd
    sccache
    xcodes
    xcodeSetup
  ];

  shellHook = ''
    unset SDKROOT NIX_CFLAGS_COMPILE NIX_LDFLAGS MACOSX_DEPLOYMENT_TARGET \
      CC CXX LD AR NM RANLIB STRIP OBJC OBJCXX

    ___helium_check_xcode() {
      local xcode xcode_version xcode_ok
      ${resolveXcode}

      if [ -z "$xcode_version" ]; then
        echo "helium: no full Xcode found (got '$xcode'); run helium-xcode-setup" >&2
        return
      fi
      export DEVELOPER_DIR="$xcode"

      if [ -z "$xcode_ok" ]; then
        echo "helium: Xcode $xcode_version at $xcode is too old (need ${toString minXcodeMajor}+); run helium-xcode-setup" >&2
      fi

      if ! /usr/bin/xcrun -f metal >/dev/null 2>&1; then
        echo "helium: Metal toolchain missing; run helium-xcode-setup" >&2
      fi
    }
    ___helium_check_xcode
    unset -f ___helium_check_xcode
  '';

  meta.platforms = lib.platforms.darwin;
}
