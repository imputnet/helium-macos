# Passkeys on macOS

This document covers the macOS passkey path that applies to Helium builds,
with an emphasis on facts that can be verified from this repository, Apple
documentation, and signed Helium app bundles.

## Overview

Getting Apple Passwords and passkeys working in Helium depends on three
separate pieces:

1. The app must be signed with Apple's managed browser passkey entitlement.
1. macOS must allow Helium to access passkeys for web browsers.
1. The Passwords app must already have a matching password or passkey for the
   relying party.

If any of those pieces is missing, the user may only see the cross-device QR
flow, or Helium may reach the Passwords app but show that no matching
passwords or passkeys exist for the current site.

## Build-time requirements

This repo already contains the passkey-related entitlement template:

- `entitlements/app-entitlements.plist` is the default app entitlement file.
- `entitlements/app-entitlements-all.plist` adds
  `com.apple.developer.web-browser.public-key-credential` and the WebAuthn
  keychain access groups.

At signing time, `sign_and_package_app.sh` only switches to
`app-entitlements-all.plist` when
`PROD_MACOS_SPECIAL_ENTITLEMENTS_PROFILE_PATH` is set. That provisioning
profile is required because `com.apple.developer.web-browser.public-key-credential`
is an Apple-managed entitlement.

In other words:

- a development or ad-hoc build can still run without the special profile
- but a build signed without that profile will not ship with the Apple browser
  passkey entitlement

The current build guide already documents this profile requirement in
`docs/building.md`.

## Verifying a built app

To verify that a Helium app bundle is actually signed for Apple browser
passkeys, inspect both the signed entitlements and the embedded provisioning
profile.

```sh
codesign -d --entitlements :- /Applications/Helium.app
security cms -D -i /Applications/Helium.app/Contents/embedded.provisionprofile | plutil -p -
```

In both outputs, look for:

- `com.apple.developer.web-browser.public-key-credential = true`

The signed app may also include passkey-related keychain access groups such as:

- `*.webauthn`
- `*.webauthn-uvk`
- `*.unexportable-keys`

## Runtime requirements

Apple documents a separate runtime permission for third-party browsers on
macOS:

- `System Settings > Privacy & Security > Passkeys Access for Web Browsers`

Apple also documents these related settings for Passwords and AutoFill:

- `System Settings > General > AutoFill & Passwords`
- `AutoFill Passwords and Passkeys`
- `Passwords > Get Browser Extension` for supported third-party browsers

Reaching the Passwords app is not the same thing as having a matching
credential. If Helium opens Passwords and Passwords says there are no
passwords or passkeys for the current site, that means browser access is
working and the missing piece is the saved credential for that relying party.

## Troubleshooting

### QR code only

If the browser only shows the QR sheet with "Use your phone or tablet", the
site has fallen back to the cross-device flow. In practical terms, Helium did
not present a usable local Apple passkey to the site.

Check:

- `System Settings > Privacy & Security > Passkeys Access for Web Browsers`
- whether Helium was fully quit and reopened after changing that setting

### Resetting the browser passkey permission

If Helium was previously allowed or denied and the permission state appears
stuck, reset the macOS privacy decision and let Helium prompt again:

```sh
tccutil reset WebBrowserPublicKeyCredential net.imput.helium
```

On a macOS 26 system, this service name can be confirmed from `tccd`:

```sh
strings -a /System/Library/PrivateFrameworks/TCC.framework/Support/tccd | rg 'WebBrowserPublicKeyCredential|kTCCServiceWebBrowserPublicKeyCredential'
```

After resetting, fully quit Helium, reopen it, and trigger the passkey flow
again.

### Passwords says there is no matching password or passkey

This is no longer an entitlement problem. It means Helium reached the Apple
Passwords UI, but Passwords did not have a matching credential for the current
site.

Typical causes:

- no passkey was ever created for that site
- the credential only exists in another password manager or browser store
- the user is looking for a Keychain Access item that is not a website/app
  password or passkey

## Data migration limits

Apple's documentation is strict here:

- Keychain Access cannot export passwords.
- Passwords on macOS imports passwords from CSV.
- Apple does not document a passkey import flow into Passwords.

This means Helium docs should not promise:

- a one-click migration from Keychain Access into Passwords
- passkey export/import from Keychain Access
- automatic conversion of all legacy keychain items into Passwords entries

Keychain Access remains relevant for items such as certificates, keys, and
other keychain records that Passwords does not present.

## References

- [Passkey use in web browsers](https://developer.apple.com/documentation/authenticationservices/passkey-use-in-web-browsers)
- [Provisioning with managed capabilities](https://developer.apple.com/help/account/reference/provisioning-with-managed-capabilities/)
- [Request access to managed capabilities](https://developer.apple.com/help/account/capabilities/capability-requests)
- [Allow third-party browsers to use your saved passkeys on Mac](https://support.apple.com/en-lk/guide/mac-help/mchl211c911f/mac)
- [Open Passwords for me](https://support.apple.com/en-lamr/120758)
- [Get Passwords extensions for a third-party browser on Mac](https://support.apple.com/en-ge/guide/passwords/mchlf7ac261e/mac)
- [Import passwords into Passwords on Mac](https://support.apple.com/is-is/guide/passwords/mchl2f1a184c/mac)
- [Export keychain items from Keychain Access on Mac](https://support.apple.com/en-euro/guide/keychain-access/kyca35961/mac)
