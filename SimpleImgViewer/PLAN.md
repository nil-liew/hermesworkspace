# SimpleImgViewer — Implementation Plan

## Project Overview
A macOS SwiftUI image viewer with keyboard shortcuts, slide show, voice control, and auto-orientation features.

## Technology Stack
- **Swift 5.9+**
- **SwiftUI** (macOS 13+ target)
- **AppKit** (keyboard event monitoring, drag-and-drop)
- **AVFoundation** (image loading, GIF support)
- **Vision Framework** (auto-orientation detection)
- **Speech Framework** (voice commands)
- **No external dependencies** (pure Apple frameworks)

---

## Phases (Ordered by Complexity)

### Phase 1: Core Image Display ✅ (COMPLETED)
- [x] SwiftUI app shell with main viewer window
- [x] Load single image (any format) via file picker
- [x] Display image centered in window
- [x] Support: PNG, JPG, HEIC, TIFF, BMP, GIF (static)
- [x] Auto-fit image to window (maintain aspect ratio)
- [x] Keyboard shortcut: `0` to toggle between original size and fit-to-window
- [x] Keyboard shortcuts: `←` `→` to navigate between loaded images
- [x] Keyboard shortcuts: `[` `]` to rotate clockwise/counter-clockwise
- [x] Keyboard shortcut: `p` to toggle collapsible sidebar
- [x] Drag-and-drop support
- [x] Auto-hide controls after 3 seconds
- [x] Phase indicator badge for testing

**Files:**
- `SimpleImgViewerApp.swift` — App entry point
- `ContentView.swift` — Main image display view
- `ImageStore.swift` — View model for managing current image
- `ImageListPanel.swift` — Collapsible sidebar with thumbnails

---

### Phase 2: Image List Panel (NEXT)
- [ ] Thumbnail grid of all loaded images (already scaffolded)
- [ ] Click thumbnail to switch image (already works)
- [ ] Visual indicator for currently selected image (already works)
- [ ] **Drag multiple files at once**
- [ ] **Remove individual images from list**
- [ ] **Reorder images in list (drag to reorder)**

---

### Phase 3: Slide Show Control
- [ ] Auto-play timer with decimal precision (0.1s increments)
- [ ] Random play mode toggle
- [ ] Start/stop slide show button
- [ ] Display current timing in UI
- [ ] Pause/resume functionality

---

### Phase 4: Voice Commands
- [ ] "Next" → go to next image
- [ ] "Previous" → go to previous image
- [ ] On-screen voice button (or microphone icon)
- [ ] Permission handling (macOS requires authorization)

---

### Phase 5: Auto-Orientate
- [ ] Scan image for dominant subject orientation
- [ ] Detect portrait vs landscape
- [ ] Update thumbnail orientation in list panel
- [ ] Save orientation metadata (optional: XMP sidecar or SQLite)

---

### Phase 6: Polish & Extras
- [ ] Window management: hide title bar, custom chrome
- [ ] Settings/preferences panel
- [ ] Dark mode support (Cinema Dark Mode aesthetic)

---

## Feature Summary Table

| Feature | Shortcut/Button | Status |
|---------|----------------|--------|
| Load images | `Cmd+O` or drag-drop | ✅ Done |
| Toggle sidebar | `p` | ✅ Done |
| Fit/original toggle | `0` | ✅ Done |
| Prev/next image | `←` `→` | ✅ Done |
| Rotate CW/CCW | `]` / `[` | ✅ Done |
| Start slide show | UI button + timer input | Phase 3 |
| Random play | UI toggle | Phase 3 |
| Voice "next/prev" | Mic button | Phase 4 |
| Auto-orientate | Background scan | Phase 5 |

---

## Testing Workflow
Each phase is built and tested independently before moving to the next.
- Manual testing required (no programmatic UI automation for macOS)
- Run as: `cd SimpleImgViewer && .build/debug/SimpleImgViewer`

---

## Current Phase: Phase 2
**Ready for your testing.** Please try:
1. Launch the app: `.build/debug/SimpleImgViewer`
2. Press `Cmd+O` to load images (try multiple)
3. Press `p` to toggle the sidebar
4. Press `←` `→` to navigate between images
5. Press `]` `[` to rotate
6. Press `0` to toggle fit/original size
7. Drop images onto the window

Report any bugs or requested changes before we proceed to Phase 3 (slide show).
