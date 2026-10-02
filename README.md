<p align="center"><a href="https://github.com/portapps/brave-nightly-portable/releases/latest" target="_blank"><img width="100" src="https://github.com/portapps/brave-nightly-portable/blob/master/res/papp.png"></a></p>

<p align="center">
  <a href="https://github.com/portapps/brave-nightly-portable/actions?workflow=build"><img src="https://img.shields.io/github/actions/workflow/status/portapps/brave-nightly-portable/build.yml?label=build&logo=github&style=flat-square" alt="Build Status"></a>
  <a href="https://github.com/portapps/brave-nightly-portable/releases"><img src="https://img.shields.io/github/v/release/portapps/brave-nightly-portable?label=release&logo=github&style=flat-square" alt="Latest release"></a>
</p>

## Notice of Non-Affiliation and Disclaimer

This app is not affiliated, associated, authorized, endorsed by, or in any way officially connected with Brave™, or any of its subsidiaries or its affiliates. It is also **not** an official Portapps app and is not listed on portapps.io.

The official Brave™ website can be found at https://brave.com.

The name Brave™ as well as related names, marks, emblems and images are registered trademarks of their respective owners.

## About

**Brave™ Nightly** portable app for Windows, made with 🚀 [Portapps](https://github.com/portapps).

Brave Nightly is the testing and development channel of Brave. It is released every night and **can be unstable** – expect bugs, crashes and data loss in the browser profile.

Unlike the stable [Brave portable app](https://portapps.io/app/brave-portable/), there is no rolling "latest" download for Nightly. The binary is therefore built from the official GitHub release of the channel and pinned to a concrete version in [`build.properties`](build.properties):

* app version: the newest `sparkle:shortVersionString` of the [Nightly appcast](https://updates.bravesoftware.com/sparkle/Brave-Browser/nightly/appcast.xml) (without a trailing `.0`)
* artifact: `brave-v<version>-win32-x64.zip` from the [`brave/brave-browser`](https://github.com/brave/brave-browser/releases) release of the same tag

This archive has the same layout as a regular Brave installation (`brave.exe` plus a Chromium version folder), so it is unpacked as is – no embedded installer has to be resolved first.

A new build is created automatically when a new Nightly version shows up in the appcast. Nightly builds share the registry keys `HKCU\SOFTWARE\BraveSoftware` with the other Brave channels, but the browser profile is kept separate through `--user-data-dir`.

## Contributing

Want to contribute? Awesome! The most basic way to show your support is to star the project, or to raise issues. If
you want to open a pull request, please read the [contributing guidelines](https://portapps.io/doc/contribute/).

You can also support this project by [**becoming a sponsor on GitHub**](https://github.com/sponsors/crazy-max) or by
making a [Paypal donation](https://www.paypal.me/crazyws) to ensure this journey continues indefinitely!

Thanks again for your support, it is much appreciated! :pray:

## License

MIT. See `LICENSE` for more details.<br>
Rocket icon credit to [Squid Ink](http://thesquid.ink).
