> [!warning]
> We have moved to https://source.extera.xyz/Extera/Extera

# Extera

[![#extera:extera.xyz](https://img.shields.io/matrix/extera:extera.xyz.svg?fetchMode=summary&server_fqdn=matrix.org)](https://matrix.to/#/#extera:extera.xyz) [![Issue tracker](https://img.shields.io/github/issues/ExteraApp/Extera)](https://github.com/ExteraApp/Extera/issues)

A FluffyChat fork on steroids, aimed at adding more features.

## Features

### Core messaging
- Send/receive all kinds of messages: text, images, videos, voice, files, polls...
- Geolocation sharing with in-app map preview
- Push notifications
- Room moderation
- Custom emotes and stickers
- Spaces
- 1-to-1 voice/video calls
- Group calls compatible with Element Call (powered by LiveKit)

### Security and privacy
- E2EE encryption using Matrix's `libvodozemac`
- Encrypted key backup
- Emoji verification and cross-signing

### UI and design
- Dark mode
- AMOLED (pitch black) mode
- Customisable seed color & color scheme
- Material You design, partially inspired by Material 3 Expressive

### Moderation
- Feature-rich group moderation (all Matrix features)
- Redacted message recovery (for Synapse admins)

### Extera Exclusives
- Built-in message translation (toggleable)
- Built-in image editor
- More expressive profiles: "About", banner, Rich Presence (MSC4320)

## Supported languages
> [!WARNING]
> We use LLMs for translating the app. Exceptions are English and Russian.

- **English**
- **Russian**
- Japanese
- German
- Spanish
- Korean
- Dutch

Other locales are not updated.

## Building

### Prerequisites
Before building, you should have:
1. Flutter SDK installed
2. [matrix-dart-sdk](https://github.com/ExteraApp/matrix-dart-sdk) in the same directory as Extera

### Setup

The `matrix` dependency can be configured in two ways:

**Way 1: Directory-based (recommended when developing both app & sdk)**
Make sure that you have `matrix-dart-sdk` cloned in the same parent directory.
```
$ ls
Extera    matrix-dart-sdk
```

**Option 2: Git reference**
Make sure that `pubspec.yaml` has a Git reference like this:
```yaml
matrix:
  git:
    url: https://github.com/ExteraApp/matrix-dart-sdk.git
    ref: main
```

### Build Commands

Platform-specific build scripts are available in the `scripts/` directory:
- `./scripts/build-appimage.sh` - AppImage (Linux)
- `./scripts/build-linux.sh` - Linux (Run only after build-appimage.sh)
- `.\scripts\build-windows.ps1` - Windows


#### Prerequisites
##### Windows 

Before building on Windows, install the following:

* **[Visual Studio Build Tools 2026](https://visualstudio.microsoft.com/downloads/#visual-studio-2022-tools)** (or newer) with the **"Desktop development with C++"** workload — provides MSVC compiler and Windows SDK.
* **[CMake](https://cmake.org/download/)**
* **[Rust](https://rustup.rs)** (`rustup`) 
* **[NASM](https://www.nasm.us/)**
* **[OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)**
* **[Flutter SDK](https://docs.flutter.dev/get-started/install/windows)**
> [!IMPORTANT]
> 1. Make sure to run build as admin.
> 2. If you are in Russia, you won't be able to download some dependencies, what will result in build failure. Use helper programs which 'alter your internet traffic'.

## License

This project is licensed under the [AGPL-3.0 License](LICENSE). See the LICENSE file for details.

## Resources

- [Matrix room](https://matrix.to/#/#extera:extera.xyz) - Support room for Extera
- [Matrix.org](https://matrix.org/) - The Matrix protocol specification
- [FluffyChat](https://github.com/krille-chan/fluffychat) - The original FluffyChat project
- [matrix-dart-sdk](https://github.com/ExteraApp/matrix-dart-sdk) - Dart SDK for Matrix (a fork of [famedly/matrix-dart-sdk](https://github.com/famedly/matrix-dart-sdk))
