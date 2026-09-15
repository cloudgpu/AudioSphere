# AudioSphere

A stunning **macOS native** audio effects app built with **SwiftUI** and
**AVFoundation**, following Apple's Human Interface Guidelines with native
glass/vibrancy materials.

## Features

- **Reverb** — 7 factory presets (Small/Medium/Large Room, Medium/Large Hall,
  Cathedral, Plate) with wet/dry mix control
- **3D Sound** — HRTF-based spatial audio with inverse distance attenuation
- **Virtual Surround** — orbit the audio source around the listener with
  adjustable angle (−180° to 180°) and distance (0.5–10 m)
- **Transport** — play/pause/stop with live seek bar and time tracking
- **Master volume** control

## Audio graph

```
PlayerNode → AVAudioUnitReverb → AVAudioEnvironmentNode → MainMixer → Output
```

## Requirements

- macOS 14+ (Sonoma)
- Xcode 15+ / Swift 5.10+

## Build

```sh
swift build
```

## Run

```sh
swift run
# or launch the built binary:
open .build/debug/AudioSphere
```

## UI

- Native glass effects (`.ultraThinMaterial`, `.bar`) per macOS HIG
- Sidebar navigation, unified toolbar, split view layout
- Animated waveform background while playing
- Settings scene for preferences

## Project layout

```
AudioSphere/
├── Package.swift
└── Sources/AudioSphere/
    ├── AudioSphereApp.swift      # entry point
    ├── AudioEngine.swift         # AVAudioEngine graph + effects
    ├── ContentView.swift         # main UI, glass cards, controls
    ├── WaveformBackground.swift  # animated visualizer
    └── SettingsView.swift        # preferences
```
