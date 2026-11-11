# another.Music

Modern, native music player for macOS and Android with intelligent AutoMix, turntable vinyl UI, and synced lyrics.

[![Website](https://img.shields.io/badge/Website-another.Music-fa2d48?style=flat&logo=googlechrome&logoColor=white)](https://jinkun1998.github.io/another.Music/)
[![Latest Release](https://img.shields.io/github/v/release/jinkun1998/another.Music?color=2997ff)](https://github.com/jinkun1998/another.Music/releases/latest)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Android-green.svg)](#features)

Website: **[https://jinkun1998.github.io/another.Music/](https://jinkun1998.github.io/another.Music/)**

---

## Highlights

- **Dual Native Architecture**: 100% native Swift / SwiftUI / AVFoundation on macOS; Kotlin / Jetpack Compose / Media3 on Android. No heavy web runtimes.
- **Intelligent AutoMix**: Beat-aligned transitions and 3-band EQ bass swaps between tracks, plus standard crossfade and gapless playback.
- **Interactive Turntable Vinyl**: Realistic spinning record with direct tonearm needle scrubbing and haptic feedback.
- **Foldable & Tablet Optimized**: Responsive dual-pane layouts tailored for inner/outer foldable displays and tablets.
- **Synced Lyrics**: Real-time line-by-line synchronized LRC lyrics powered by LRCLIB and SimpMusic.
- **macOS System Integration**: Menu bar mini controller, MediaRemote Now Playing info, and companion cover art export for [anotherNotch](https://jinkun1998.github.io/another.notch/).
- **iCloud Sync**: Seamless library, favorites, and playlist synchronization across Apple devices.

---

## Download & Installation

Visit the [Website](https://jinkun1998.github.io/another.Music/) or download from [Releases](https://github.com/jinkun1998/another.Music/releases/latest):

- **macOS**: `anotherMusic-macOS.dmg` or portable `.app` (macOS 14 Sonoma or later)
  *(If Gatekeeper blocks first launch: `xattr -cr /Applications/anotherMusic.app`)*
- **Android**: `anotherMusic-android.apk` (Android 8.0 Oreo or later, optimized for foldables)

---

## Building from Source

### macOS (Swift 6 / macOS 14+)

```bash
# Build standalone bundle and test
./macos/bundle.sh run

# Generate DMG installer
./macos/bundle.sh dmg
```

### Android (JDK 17 / Android SDK 35)

```bash
# Assemble debug APK
./gradlew assembleDebug

# Assemble release APK
./gradlew assembleRelease
```

---

## Attribution & Thanks

another.Music is based on and forked from [Mochy-Music](https://github.com/realidkroo/Mochy-Music) by [realidkroo](https://github.com/realidkroo). Sincere thanks to realidkroo and upstream contributors for the original Android design and InnerTube architecture.

Upstream dependencies and inspirations:
- [ViviMusic](https://github.com/vivizzz007/vivi-music) & [Metrolist](https://github.com/mostafaalagamy/Metrolist)
- [RiMusic / InnerTube](https://github.com/fast4x/RiMusic)
- [LRCLIB](https://lrclib.net/) & [SimpMusic](https://github.com/maxrave-dev/SimpMusic)

---

## License

Licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html). Original copyright and GPL-3.0 notices are retained.
