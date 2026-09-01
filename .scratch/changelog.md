# changelog

## 2026-08-31 — swiftui-macos-gotchas: keyboard shortcuts fix documented

Added two new sections to `swiftui-macos-gotchas` skill:
- **Keyboard Shortcuts That Don't Work** — documents failed approaches (overlay buttons, NSView bridge, onKeyPress) and why they fail
- **SPM Project Layout Gotcha** — notes that AppDelegate must be in `Sources/` for SPM projects

Created `references/mp3-trimmer-shortcuts-debug.md` with full implementation pattern using `NSEvent.addLocalMonitorForEvents` + NotificationCenter, which is the working solution for macOS 13+ shortcut handling in SwiftUI.
