---
type: concept
title: SimpleVLCPlayer Architecture Review
description: Current state analysis and recommendations for SimpleVLCPlayer media player
updated: 2026-08-20
tags: [architecture, review, swift, avfoundation]
---

# SimpleVLCPlayer Architecture Review

## Current State Assessment

### Project Structure
```
SimpleVLCPlayer/
├── Package.swift              # Swift Package, macOS 14+
└── Sources/
    ├── SimpleVLCPlayerApp.swift  # App entry + AppDelegate (drag-drop, file open)
    ├── ContentView.swift         # Main UI, controls, progress bar
    ├── PlayerModel.swift         # AVPlayer logic + color constants
    └── DropTarget.swift          # Drag-drop NSView (UNUSED)
```

### What Works
- Basic video playback with AVFoundation
- Hidden title bar (Cinema Dark Mode)
- Skip controls (±15s)
- Progress bar with seek gesture
- File open via menu or drag-drop
- Rotation support
- Builds successfully

### Key Issues Identified

#### 1. Unused Code
- `DropTarget.swift` is never used — `ContentView` uses `fileImporter` instead
- Duplicate `URLSupportsVideo()` in both `ContentView.swift` and `DropTarget.swift`

#### 2. Separation of Concerns Violations
- Color constants mixed into `PlayerModel.swift` (should be in separate file or enum)
- `AppDelegate` handles both window management and drag-drop registration
- No clear boundary between UI, business logic, and data

#### 3. Scalability Gaps
- No playlist system
- No settings persistence layer
- No SMB/network URL support
- No model for future features

#### 4. Architecture Debt
- Single `PlayerModel` class doing everything
- No dependency injection
- No error handling for playback failures
- No volume control (mentioned in UI requirements but not implemented)

---

## Prioritized Recommendations

### P0: Immediate Cleanup
1. Delete `DropTarget.swift` (unused)
2. Consolidate `URLSupportsVideo()` to single location
3. Move color constants to dedicated `Colors.swift`

### P1: Core Architecture (Pre-Feature Work)
Create these foundational components:

```
Sources/
├── SimpleVLCPlayerApp.swift
├── ContentView.swift
├── Models/
│   ├── PlayerModel.swift      # AVPlayer wrapper, playback state
│   ├── PlaylistModel.swift    # Queue management (future)
│   └── SettingsModel.swift    # Persistence (future)
├── Views/
│   ├── VideoView.swift        # AVPlayerView wrapper
│   ├── ControlsBar.swift      # Playback controls
│   ├── ProgressBar.swift      # Seek bar
│   └── EmptyState.swift       # No video state
└── Utilities/
    ├── Colors.swift           # Cinema Dark Mode palette
    ├── FileHelpers.swift      # URL validation, extensions
    └── TimeFormatter.swift    # Time display formatting
```

### P2: Dependency Injection
- Make `PlayerModel` injectable (for testing and flexibility)
- Use `@EnvironmentObject` or pass player as parameter

### P3: Feature Preparation
- Add settings structure (even if placeholder)
- Plan playlist data model
- Consider VLCKit integration point (wrapper protocol)

---

## Future Feature Roadmap

1. **Playlist Queue** — `PlaylistModel` with array of URLs, current index
2. **SMB Support** — Network URL handler, Keychain for credentials
3. **Settings Panel** — Persistence via UserDefaults or JSON file
4. **VLCKit Migration** — Protocol abstraction for video engine swap
5. **Volume Control** — Slider in bottom bar (currently absent)

---

## Next Steps

1. Execute P0 cleanup (delete unused files, consolidate)
2. Create new directory structure (Models/, Views/, Utilities/)
3. Migrate code into separated components
4. Validate build after each migration step
