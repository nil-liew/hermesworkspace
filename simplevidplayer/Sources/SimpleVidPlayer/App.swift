import SwiftUI

@main
struct SimpleVidPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 560)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    weak var playerVM: PlayerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        // Center the window on launch
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { return }
            window.center()
        }

        // Press-and-hold ← / → handling lives in PlayerViewModel's own NSEvent monitor.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
