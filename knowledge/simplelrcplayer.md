---
type: concept
title: SimpleLRCPlayer
description: Minimal SwiftUI MP3 player with LRC lyrics sync. Play/pause + auto-loaded lyrics.
updated: 2026-09-11
---

# SimpleLRCPlayer

Minimal MP3 player with synced LRC lyrics display.

## Tech Stack
- SwiftUI + AVFoundation
- macOS 14.0 target
- Hidden title bar, minimal UI

## Features
- Drag-drop or Cmd+O to load MP3
- Auto-load `.lrc` from same folder (same base name)
- Play/pause button
- Timed LRC highlight + auto-scroll
- Space shortcut for play/pause

## File Structure
```
simplelrcplayer/
├── Sources/
│   └── SimpleLRCPlayer/
│       ├── App.swift
│       ├── PlayerViewModel.swift
│       ├── LrcParser.swift
│       └── ContentView.swift
├── Project.yml
└── .gitignore
```

## Build
```bash
xcodegen generate
xcodebuild -project SimpleLRCPlayer.xcodeproj -scheme SimpleLRCPlayer build
open DerivedData/Build/Products/Debug/SimpleLRCPlayer.app
```
