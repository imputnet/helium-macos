# Air
macOS packaging & development tooling for the Air Browser (derived from
[Helium](https://github.com/imputnet/helium)).

## Building and development
macOS is our primary development platform, so it's the recommended environment
for developing new Helium features.

[> See docs/building.md](docs/building.md)

## Contributing
Before contributing to this repo, please read the guidelines in the main repo's
[CONTRIBUTING.md](https://github.com/imputnet/helium/blob/main/CONTRIBUTING.md).

## Name

The project is called "Air" (sometimes referenced historically as "Air Browser").
The name reflects our heritage and intent: the codebase is derived from
Helium and incorporates influences from Arc, so the short, lightweight name
"Air" represents a blend of those inspirations and the project's focus on a
clean, lightweight browsing experience.

## Credits

### Depot
Big thank you to [Depot](https://depot.dev/) for sponsoring our runners,
which handle the macOS builds of Helium. Their high-performance infrastructure
lets us compile, package, and release new builds of Helium within hours,
not days.

### ungoogled-chromium-macos
This repo is based on
[ungoogled-chromium-macos](https://github.com/ungoogled-software/ungoogled-chromium-macos),
but heavily modified for Helium. Special thanks to everyone behind
ungoogled-chromium, they made working with Chromium infinitely easier.

## License
All code, patches, modified portions of imported code or patches, and
any other content that is unique to Helium and not imported from other
repositories is licensed under GPL-3.0. See [LICENSE](LICENSE).

Any content imported from other projects retains its original license (for
example, any original unmodified code imported from ungoogled-chromium remains
licensed under their [BSD 3-Clause license](LICENSE.ungoogled_chromium)).

## Logo

Air Browser uses the official logo stored in the repository at [resources/assets/air-browser.ai](resources/assets/air-browser.ai).

We keep a single, canonical logo source to ensure consistent branding across
the application and distribution artifacts (app bundle, DMG, website). Using
the repository asset prevents accidental redesigns, simplifies icon generation
for different sizes and platforms, and helps users recognize the app quickly.
