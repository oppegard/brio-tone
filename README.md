# BrioTone

> A minimalist macOS menu-bar app that fixes the color of the **Logitech MX Brio** (and other UVC webcams) at the **sensor level** — warm/cinematic presets, manual exposure & focus, and framing, applied to every app at once with **no virtual camera**.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-000000?logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-✓-success)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI%20MenuBarExtra-0A84FF)
![License](https://img.shields.io/badge/license-MIT-blue)

The MX Brio ships with a noticeably **cold/blue, over-saturated** image (auto white balance sits around ~4300 K and reads blue). BrioTone drives the camera's real **UVC controls** to make the picture warmer and more natural — closer to how Apple renders — and turns the webcam into a properly controllable camera with **locked exposure, focus, and white balance** for a stable, professional look.

Because adjustments are written **directly to the camera hardware over UVC**, they apply system-wide: **Zoom, Google Meet, Microsoft Teams, FaceTime, QuickTime, OBS** — all at once, with no virtual-camera layer to install.

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [Cinematic presets](#cinematic-presets)
- [How it works](#how-it-works)
- [Project structure](#project-structure)
- [Optional: Apple-style LUT layer (OBS)](#optional-apple-style-lut-layer-obs)
- [Troubleshooting](#troubleshooting)
- [Limitations](#limitations)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Features

Organized into three tabs to keep the popover compact:

- **Color** — white balance (2800–7500 K) with Auto, saturation, contrast, sharpness, brightness.
- **Exposure** — the pro upgrade: turn off Auto and lock **shutter** (shown as `1/x s`) and **ISO/gain**; backlight compensation; anti-flicker (50/60 Hz).
- **Framing** — auto-focus toggle + manual focus distance, **zoom** (1×–4× on the 4K sensor), and **pan/tilt** when zoomed in.

Plus:

- **Presets** that capture the *entire* state (color + exposure + framing), including six built in and your own saved looks.
- **Apply at login** — re-applies your last look on startup.
- **System-wide** — no virtual camera, no LUT, affects every app simultaneously.

## Requirements

- macOS **14.0+** (built and tested on macOS 26, Apple Silicon).
- A UVC webcam. Tuned for the **Logitech MX Brio** (`046d:0944`); other UVC cameras work but exposed controls/ranges vary.
- **Xcode** / Swift toolchain and **git** (to build).

## Install

```bash
git clone https://github.com/johanvillalbab/brio-tone.git
cd brio-tone
./build.sh            # compiles uvc-util + the app, assembles dist/BrioTone.app
open dist/BrioTone.app # a camera icon appears in the menu bar
```

`build.sh` compiles the [`uvc-util`](https://github.com/jtfrey/uvc-util) helper from source on first run (no binaries are committed to this repo), builds the Swift package, assembles the `.app`, and ad-hoc signs it.

To launch automatically: **System Settings → General → Login Items → +** and add `dist/BrioTone.app`.

## Usage

Click the camera icon in the menu bar, then:

1. Pick a starting point from **Load preset** (e.g. *Cine — Cálido* or *Apple-ish*).
2. Fine-tune with the sliders — changes apply **live** to the camera.
3. Save your own look with **＋ → name it**. Presets store color, exposure, and framing.

**The one dial to know — ISO/gain.** The cinematic presets *lock* exposure (that's what makes the image stable and professional), so the correct brightness depends on **your** lighting:

- Image too dark → raise **ISO** (Exposure tab).
- Image washed out → lower it.
- Keep ISO **as low as possible** for a clean, noise-free image. That's the golden rule.

## Cinematic presets

All share the same DNA: **locked white balance + locked exposure at a 1/60 s shutter** (the 180° rule at 30 fps → natural motion blur), **low sharpness** (kills webcam over-sharpening), and a **flatter, graded** color base.

| Preset | Best for | Key traits |
|---|---|---|
| 🎬 **Cine — Cálido (1/60)** | Well-lit room | Warm 6200 K, soft, clean, gain 40 |
| 🎬 **Cine — Plano/Neutro** | Controlled / gradeable | Flat contrast, neutral 5500 K, very low sharpness |
| 🎬 **Cine — Low Key (noche)** | Dim / evening | Punchy contrast, darker, 1/50 s + gain 120 |

Also included: **Apple-ish (warm)**, **Neutral**, and **Logitech (default)**.

## How it works

The MX Brio exposes its image pipeline through standard **USB Video Class (UVC)** controls. BrioTone wraps the [`uvc-util`](https://github.com/jtfrey/uvc-util) command-line tool to read and write them (`white-balance-temp`, `saturation`, `contrast`, `sharpness`, `brightness`, `auto-exposure-mode`, `exposure-time-abs`, `gain`, `auto-focus`, `focus-abs`, `zoom-abs`, `pan-tilt-abs`, …).

These are **hardware controls on the camera itself**, so any app that opens the webcam sees the corrected image — there is no frame processing and no virtual camera. The trade-off: UVC can't do per-color remapping (a 3D LUT), so color is limited to global white balance / saturation / contrast / brightness. For LUT-style grading see [the optional OBS layer](#optional-apple-style-lut-layer-obs).

> **Empirical note:** the MX Brio runs cold. On this camera, a *higher* white-balance value = a *warmer* image (verified by capturing frames at 2800 K vs 7500 K). The presets lean warm to counter the factory blue cast.

## Project structure

```
brio-tone/
├── Package.swift              # SwiftPM executable target
├── Info.plist                 # LSUIElement (menu-bar agent) bundle metadata
├── build.sh                   # Builds uvc-util + app, assembles & signs dist/BrioTone.app
├── Sources/BrioTone/
│   ├── BrioToneApp.swift      # @main, SwiftUI MenuBarExtra
│   ├── ContentView.swift      # Color / Exposure / Framing UI
│   ├── AppModel.swift         # Observable state, debounced live apply
│   ├── CameraController.swift # Wraps uvc-util (device discovery, get/set)
│   └── Presets.swift          # CameraState model, built-in presets, persistence
└── obs-apple-look/            # Optional LUT layer (see below)
```

User presets and last-applied state are stored in `~/Library/Application Support/BrioTone/`.

## Optional: Apple-style LUT layer (OBS)

Sensor controls fix coldness/saturation/contrast everywhere. For fine **Apple-style skin-tone** remapping you need a 3D LUT over a virtual camera. The `obs-apple-look/` folder contains a parametric LUT generator (`generate_lut.py`, numpy) that produces custom `.cube` files tuned for the MX Brio, plus `SETUP.md` for loading them in OBS and exposing the OBS virtual camera to Zoom/Meet/Teams.

> Don't stack color twice — with the LUT active, set BrioTone to the **Neutral** preset and let the LUT do the grading.

## Troubleshooting

- **"No UVC webcam connected"** — replug the camera and click the refresh icon. Built-in MacBook and Continuity (iPhone) cameras are *not* UVC and won't appear.
- **Sliders are disabled** — no device detected, or the related **Auto** toggle is on (turn off Auto to set white balance / exposure / focus manually).
- **The image looks different when a call starts** — some webcams re-run auto-gain when an app first opens the stream. Re-select your preset once and it sticks. (Manual white balance holds during streaming.)
- **macOS blocks the app** — it's ad-hoc signed; right-click `BrioTone.app` → **Open** the first time.

## Limitations

- UVC provides global color only (no hue/tint/vibrance or per-color LUT on this device).
- Exposed controls and value ranges depend on the camera model.
- Not affiliated with or endorsed by Logitech or Apple. "Logitech", "MX Brio", and "Apple" are trademarks of their respective owners.

## Acknowledgements

- [`uvc-util`](https://github.com/jtfrey/uvc-util) by **Jeffrey Frey** (MIT) — the UVC control engine. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

[MIT](LICENSE) © 2026 Johan Villalba
