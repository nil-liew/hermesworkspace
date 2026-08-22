---
type: concept
title: SimpleVLCPlayer Tickets
description: Active development tickets for SimpleVLCPlayer project
updated: 2026-08-20
---

# SimpleVLCPlayer — Development Tickets

## Ticket 1: Fix Drag-Drop File Support ✅ COMPLETED
**Status:** Done
**Assignee:** Developer Agent (deleg_e3f7d3f2)

**Changes:**
- `AppDelegate` now conforms to `NSWindowDelegate`
- In `applicationDidFinishLaunching`: registers main window as drag destination with `registerForDraggedTypes([.fileURL])`
- Implemented `window(_:performDragOperation:)` to handle dropped files at window level
- Removed `DropTarget()` overlay from SwiftUI ZStack (it was being covered by VideoView)
- Notification center pattern (`.openFile`) preserved

## Ticket 2: Remove ±10s Skip Buttons ✅ COMPLETED
**Status:** Done
**Assignee:** Developer Agent (deleg_e3f7d3f2)

**Changes:**
- Removed `skipButton(symbol: "backward.fill", label: "–10s", ...)` 
- Removed `skipButton(symbol: "forward.fill", label: "+10s", ...)`
- Kept only ±15s buttons: `gobackward.15` and `goforward.15`
- Controls bar layout simplified

## Pending Features
1. Playlist queue
2. SMB URL input + Keychain
3. SMB playback
4. Settings panel
5. `create-dmg` bundle
