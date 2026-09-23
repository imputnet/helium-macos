# macOS unframed IWA titlebar controls — issue 482535474

## Problem and expected behavior

An isolated web app (IWA) in `unframed` display mode on macOS still exposes
AppKit's close, minimize, and zoom buttons. The controls can overlap the app's
custom top border, especially after resizing. In unframed mode the titlebar and
its controls should be absent; the app supplies its own drag regions and window
UI. Chromium's issue discussion explicitly confirms this expected behavior.

The [Chromium issue](https://issues.chromium.org/issues/482535474) is closed as
Won't Fix (Infeasible) because unframed mode is currently planned only for
ChromeOS. The team said community contributions are welcome, while also making
clear that macOS launch and continued availability of the experiment are not
committed. This patch fixes the present macOS implementation; it does not change
that product decision.

## Reproduction

Tested on macOS 26.0 (arm64) with Helium 153.0.8010.52, using a separate test
profile. The Chromium report used Chrome Canary 146 on macOS 26.2; its bisect
found good build 146.0.7638.0 and bad build 146.0.7639.0.

1. Start the browser with `IsolatedWebApps`, `IsolatedWebAppDevMode`,
   `UnframedIwa`, and `WebAppBorderless` enabled.
2. At `chrome://web-app-internals/`, install Kitchen Sink IWA using its
   [update manifest](https://github.com/chromeos/iwa-sink/releases/latest/download/update.json).
3. Open Kitchen Sink IWA from `chrome://apps/`, select **Go unframed**, and allow
   window management permission.
4. Inspect the top-left corner and resize the window from its top border.

Before the patch, the three native buttons were exposed in the app window's
accessibility tree and visible against the custom border. After the patch, they
were absent in unframed mode. Blocking window management permission restored the
controls and framed layout; allowing it again removed them. These transitions
were observed through computer use on the built Helium app.

## Root cause

`BrowserView::IsUnframedModeEnabled()` becomes true when the app requests
unframed mode and has window management permission. Browser layout then hides
the web-app toolbar and lets web content reach the top edge. On macOS,
`BrowserNativeWidgetMac::PopulateCreateWindowParams()` still creates the app
window with titled, closable, miniaturizable, and resizable style bits. AppKit
therefore supplies the three standard buttons. `BrowserFrameViewMac` also
continued reserving caption-button space.

The visible IWA window lives in the remote Cocoa app-shim process. The browser
process holds a local proxy window, so changing that proxy's AppKit button views
would not affect what the user sees. A browser-to-app-shim Mojo message is
needed to update the actual `BrowserNativeWidgetWindow`.

The issue's [bisect comment](https://issues.chromium.org/issues/482535474#comment12)
identifies Chromium revision `13437964cc29becab3cce063b2156536018b16bf` as
the likely trigger for the *position* regression. That change reduced the Mac
titlebar height calculation; it did not establish that native buttons belong in
unframed mode. Restoring the old height would leave the underlying visibility
bug and affect ordinary web-app windows.

## Patch design

The patch adds `SetTitlebarButtonsVisible(bool)` to the remote Cocoa window
interface. `BrowserFrameViewMac::Layout()` sends the state when an app window
enters or exits unframed mode and stops reporting caption-button exclusions to
the browser layout while unframed. The app shim hides or shows the actual close,
minimize, and zoom button views. It reapplies the hidden state after AppKit
changes the style mask, which can replace those views. The window retains its
close, minimize, and resize style capabilities throughout.

The native-window unit test covers initial visibility, hiding, resize-style
changes, unchanged capability bits, and restoration. An existing unframed-IWA
browser test now checks the Mac caption exclusions across permission grant,
revoke, and grant. The existing test fixture in
`chrome/browser/ui/views/web_apps/frame_toolbar/web_app_frame_toolbar_browsertest.cc`
is Linux/ChromeOS-only, so Mac assertions were deliberately placed in
`chrome/browser/web_applications/isolated_web_apps/unframed_browsertest.cc`.

## Validation and remaining checks

- The patched Helium `chrome` target built successfully on this machine.
- Helium's patch-series linter passed on the updated repository branch.
- A patched Helium 153.0.8010.52 arm64 app was ad-hoc signed and packaged in
  an APFS disk image for local use. The app inside the mounted image passed
  `codesign --verify --deep --strict`; `hdiutil verify` passed for the image.
- The revised native-window unit-test object compiled.
- The macOS browser-test source compiled directly with Chromium's generated
  compiler flags. The full `browser_tests` target was not linked or run.
- Manual end-to-end testing verified button visibility in unframed, framed,
  and unframed states on the same app window.
- The final patch applies cleanly to Helium's prepared Chromium 153 source.
  Helium's current `main` now tracks Chromium 154.0.8037.57; its patch-series
  and runtime checks on that version are pending CI or a complete prepared
  checkout.
- An independent Astra review found an unreachable Mac test in the first
  version. That test was moved to a Mac-enabled fixture; a second read-only
  review found no further actionable issues.

Before an upstream Chromium review, run the updated unit and browser tests from
a complete test checkout, then test on additional macOS versions. The
pre-existing runner source lacks
`chrome/test/data/extensions/extension_api_unittest/api_features.json`, which
blocks building the browser-test object in that prepared snapshot. No Chromium
source or test-data download was performed for this investigation. The patch
must also be rebased against current Chromium main before a Gerrit CL can be
uploaded.

## Submission notes

Helium can review the patch-series change on branch
`codex/fix-unframed-iwa-macos`. For Chromium, carry the same source changes as a
normal Gerrit CL with `Bug: 482535474`, an accurate `Test:` stanza, and owners
for the browser frame, web-app, and remote Cocoa directories. Chromium's
[contribution guide](https://chromium.googlesource.com/chromium/src/+/main/docs/contributing.md)
calls for style conformance, tests, and a reviewable change; its
[C++](https://chromium.googlesource.com/chromium/src/+/main/styleguide/c++/c++.md)
and [Objective-C++](https://chromium.googlesource.com/chromium/src/+/main/styleguide/objective-c/objective-c.md)
guides apply to this patch. A Chromium Gerrit CL has not been opened. The
commit uses `luke@agent54.org`; ensure that address is linked to the
contributor's Gerrit account before uploading it.

For a first Chromium contribution, the same guide also requires a completed
individual or corporate Contributor License Agreement and a contributor entry
in Chromium's `AUTHORS` file as part of the first CL. The patch adds
`Luke Hubbard <luke@agent54.org>` to `AUTHORS`. Ask the reviewer to run try
jobs if the account lacks try-job access. The Helium patch is based on its
Chromium 153 snapshot, so test and rebase the source changes on Chromium main
before upload.

## Local signed build

The local artifact is
`artifacts/Helium-unframed-IWA-153.0.8010.52-arm64-adhoc-apfs.dmg` in the
workspace parent directory. Its SHA-256 is
`84d9a5815a15b47086adea7b0b6559499d0d7f6d51d5ff81af2ffa4cc12d7b67`.
The app was signed with an ad-hoc signature because this machine currently has
no valid Developer ID code-signing identity. That signature verifies locally,
but the build is not notarized and is not intended for broad distribution. The
separate signed app bundle is in the adjacent `artifacts/` directory. The
binary artifacts are intentionally outside the Git repository.

Chromium's [AI coding policy](https://chromium.googlesource.com/chromium/src/+/main/agents/ai_policy.md)
requires the human submitter to review and understand AI-assisted changes,
attest to original authorship, and answer human review comments personally.
