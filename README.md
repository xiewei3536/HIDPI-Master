# HiDPI Master

**English** | [繁體中文](README.zh-Hant.md) | [简体中文](README.zh-Hans.md)

A polished macOS menu-bar app that makes external monitors (27″/32″ 2K/4K…) look **big AND crisp** — enable HiDPI (Retina 2× rendering), get a smart size recommendation based on your panel's real specs, and switch sizes in plain language instead of resolution numbers.

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Universal](https://img.shields.io/badge/chip-Intel%20%7C%20Apple%20Silicon-purple) ![Release](https://img.shields.io/github/v/release/xiewei3536/HIDPI-Master)

## Download

Grab the latest **`HiDPI-Master.dmg`** from [Releases](https://github.com/xiewei3536/HIDPI-Master/releases/latest), open it and drag the app into **Applications**.

> The app is not notarized. On first launch, right-click the app → **Open**, or allow it under **System Settings → Privacy & Security**. Alternatively: `xattr -dr com.apple.quarantine "/Applications/HiDPI Master.app"`

## Why

When you plug in a big external monitor, macOS often gives you only two bad options:

- **Native resolution** → text is too small
- **Non-Retina scaling** → UI is big enough but blurry and jagged

HiDPI Master unlocks **HiDPI (2× Retina) modes** so the UI gets bigger *and stays sharp*.

## Features

| | |
|---|---|
| 🔍 **Smart detection** | Reads each panel's physical size, native resolution and PPI |
| ⭐ **Smart recommendation** | Scores every HiDPI size by *comfortable UI size × text sharpness* for your exact panel — with plain-language reasons. Only ever recommends HiDPI, aspect-fitting modes |
| 🗣 **Human-friendly by default** | No numbers: a "bigger text ↔ more space" slider with labels like *Just right / Extra large*. Flip on **advanced mode** for full resolution/PPI data |
| ⚡ **One-click HiDPI enabling** | Intel: display override (native after one reboot, SIP untouched). Apple Silicon: virtual display + mirroring (instant, no reboot) |
| 📐 **Maximum size catalog with aspect guard** | Generates every possible HiDPI size for your panel across aspect families; sizes that don't match the screen's shape are marked ⚠ and require confirmation |
| 🎞 **Refresh-rate control** | Pick any Hz your display supports; your Hz is preserved when switching sizes |
| 🔁 **Auto-apply** | Remembers per-display setups and restores them on reconnect; launch-at-login support |
| 🔔 **Auto-update** | Checks GitHub Releases, notifies you, downloads and installs the new version in one click |
| ✨ **One-click Optimize** | One header button applies the recommended size to every external display |
| 🙋 **“I prefer” switch** | Bigger text / Balanced / More space — shifts every recommendation and size label |
| 🛟 **Safe switching** | Risky changes (refresh rate, non-HiDPI, odd aspect) get a “Does this look right?” countdown and auto-revert |
| 📏 **Size correction** | Monitor didn't report its size, or got it wrong? Pick the inch size once |
| 💾 **Persistence guard** | Detects HiDPI modes with no override file behind them (they vanish after a reboot) and saves them in one click |
| 🔁 **Apply after restart** | Pick a size before rebooting; it's applied automatically when the Mac is back |
| 🖱 **Menu-bar quick switch** | Right-click the icon to change sizes without opening the panel |
| 🌐 **Localized** | English, 繁體中文, 简体中文 — switchable live inside the app |

## How it works

| | Intel (default) | Apple Silicon (default) |
|---|---|---|
| Method | EDID override + `scale-resolutions` | `CGVirtualDisplay` + mirroring |
| Takes effect | after a reboot | instantly |
| Background app needed | no | yes (enable *Launch at login*) |
| SIP | untouched | untouched |
| Writes to | `/Library/Displays/Contents/Resources/Overrides` | nothing (runtime only) |

Intel Macs can also choose the instant virtual-display method.

## Build from source

Requires macOS 12+ and Xcode (or Command Line Tools with Swift 5.9+):

```bash
./scripts/build-app.sh          # → dist/HiDPI Master.app (universal)
./scripts/make-dist.sh          # → dist/HiDPI-Master.dmg + .zip
```

## Restore

**Settings → Restore → Restore all displays to default** turns off virtual displays and removes installed override files (admin password required). Reboot to fully clear.

## Notes

- The virtual-display method uses the same private API technique as BetterDummy/BetterDisplay and is best-effort.
- Overrides only affect the display with the matching vendor/product ID.
- Released under the [MIT License](LICENSE).
