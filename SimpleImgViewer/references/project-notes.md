# SimpleImgViewer Project Notes

## Session Context
Created on 2026-08-25. Phase 1 complete (core image display).

## Build Commands
```bash
cd /Users/daddy/hermesworkspace/SimpleImgViewer
swift build                           # Build
.build/debug/SimpleImgViewer          # Run
```

## Keyboard Shortcuts Implemented
| Key | Action |
|-----|--------|
| `Cmd+O` | Open file dialog |
| `p` | Toggle sidebar |
| `←` `→` | Prev/next image |
| `]` `[` | Rotate CW/CCW |
| `0` | Toggle fit/original size |

## Files
- `Sources/SimpleImgViewer/SimpleImgViewerApp.swift` — App entry point
- `Sources/SimpleImgViewer/ContentView.swift` — Main viewer with keyboard handling
- `Sources/SimpleImgViewer/ImageStore.swift` — State management
- `Sources/SimpleImgViewer/ImageListPanel.swift` — Sidebar thumbnails
- `PLAN.md` — Implementation plan

## Next Phase: Phase 2
- Enhance sidebar with drag-to-reorder
- Remove individual images from list
- Drag multiple files at once

## Known Issues
- None in Phase 1
- GIF animation not yet supported (static only)
