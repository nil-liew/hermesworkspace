import SwiftUI
import AppKit

@main
struct SimpleImgViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image...") {
                    NotificationCenter.default.post(name: .openImage, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openImage = Notification.Name("simpleImgViewerOpenImage")
}
