import Cocoa
import SwiftUI

@main
struct SimpleVLCPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    @objc func applicationDidFinishLaunching(_ notification: Notification) {
        // Register the main window as a drag destination for video files
        if let window = NSApplication.shared.windows.first {
            window.registerForDraggedTypes([.fileURL])
            window.delegate = self
        }
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if URLSupportsVideo(url) {
            NotificationCenter.default.post(name: .openFile, object: nil, userInfo: ["url": url])
        }
        return true
    }

    func window(_ window: NSWindow, performDragOperation info: NSDraggingInfo) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems else { return false }

        for item in items {
            if let urlStr = item.string(forType: .fileURL),
               let url = URL(string: urlStr),
               URLSupportsVideo(url) {
                NotificationCenter.default.post(name: .openFile, object: nil, userInfo: ["url": url])
                return true
            }
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
