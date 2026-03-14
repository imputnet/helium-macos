# helium-macos
macOS packaging & development tooling for [Helium](https://github.com/imputnet/helium).

## Building and development
macOS is our primary development platform, so it's the recommended environment for
developing new Helium features.

*[Go to docs/building.md](docs/building.md)*

## Additional documentation
- [Passkeys on macOS](docs/passkeys.md)

## Credits
This repo is based on
[ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos),
but heavily modified for Helium. Special thanks to everyone behind ungoogled-chromium,
they made working with Chromium infinitely easier.

A huge thank you to [Depot](https://depot.dev/) for sponsoring our runners, which handle the macOS
builds of Helium. Their high-performance infrastructure lets us compile and package Helium at least
8 times faster than with GitHub-hosted runners, allowing us to release new builds within hours, not days.

## License
All code, patches, modified portions of imported code or patches, and
any other content that is unique to Helium and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).

[comment]: # (building & development instructions still work, but can be simplified in the future)
