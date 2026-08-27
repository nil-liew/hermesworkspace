import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Simple keyboard monitor using global NSEvent hook
func setupKeyboardMonitor(for store: ImageStore, showOpenPanel: Binding<Bool>, showCheatsheet: Binding<Bool>, carouselVisible: Binding<Bool>, settingsVisible: Binding<Bool>, voice: VoiceController, toggleZoom: @escaping () -> Void) {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        print("[SIV] KeyDown: keyCode=\(event.keyCode) chars='\(event.charactersIgnoringModifiers ?? "nil")'")
        
        // Ignore Cmd and Option modifiers
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            return event
        }
        
        if let chars = event.charactersIgnoringModifiers?.lowercased(), chars.count == 1 {
            switch chars {
            case "o":
                showOpenPanel.wrappedValue = true
                return nil
            case "c":
                carouselVisible.wrappedValue.toggle()
                return nil
            case "s":
                settingsVisible.wrappedValue.toggle()
                return nil
            case "v":
                voice.toggle()
                return nil
            case "i":
                showCheatsheet.wrappedValue.toggle()
                return nil
            case "z":
                toggleZoom()
                return nil
            case "0":
                store.toggleFitToWindow()
                return nil
            case " ":
                store.toggleSlideshow()
                return nil
            case "]":
                store.rotateClockwise()
                return nil
            case "[":
                store.rotateCounterClockwise()
                return nil
            default:
                break
            }
        }
        
        switch event.keyCode {
        case 123: // Left arrow
            store.goToPrevious()
            return nil
        case 124: // Right arrow
            store.goToNext()
            return nil
        default:
            return event
        }
    }
}
