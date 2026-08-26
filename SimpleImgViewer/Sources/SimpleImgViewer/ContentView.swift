import SwiftUI
import AppKit

/// Main content view with image display and controls
struct ContentView: View {
    @StateObject private var store = ImageStore()
    @State private var showOpenPanel = false
    @State private var sidebarVisible = false
    @State private var isControlsVisible = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 0) {
                // Main image display
                mainImageSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Sidebar (collapsible)
                if sidebarVisible {
                    Divider()
                        .frame(width: 1)
                    ImageListPanel(store: store)
                        .frame(width: 240)
                }
            }
        }
        .overlay(alignment: .bottom) {
            controlsBar
        }
        .overlay(alignment: .topLeading) {
            phaseIndicator
        }
        .fileImporter(
            isPresented: $showOpenPanel,
            allowedContentTypes: [.png, .jpeg, .heic, .heif, .tiff, .bmp, .gif],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                store.loadImages(from: urls)
            case .failure: break
            }
        }
        .overlay(alignment: .topTrailing) {
            if store.isSlideshowPlaying {
                Text("▶ Slideshow  •  \(store.currentIndex + 1)/\(store.images.count)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.75))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .padding()
            }
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isControlsVisible = hovering || sidebarVisible || store.isSlideshowPlaying
            }
        }
    }
    
    // MARK: - Keyboard Event Monitor
    // Correct macOS keycodes: o=31, p=35, 0=29, [ =33, ]=30, left=123, right=124
    
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                return event
            }
            
            // Character-based matching (layout independent)
            if let chars = event.charactersIgnoringModifiers?.lowercased(), chars.count == 1 {
                switch chars {
                case "o":
                    showOpenPanel = true
                    print("[SIV] open panel requested")
                    return nil
                case "p":
                    sidebarVisible.toggle()
                    print("[SIV] sidebar -> \(sidebarVisible)")
                    return nil
                case "0":
                    store.toggleFitToWindow()
                    print("[SIV] isFitToWindow -> \(store.isFitToWindow)")
                    return nil
                case " ":
                    store.toggleSlideshow()
                    print("[SIV] slideshow -> \(store.isSlideshowPlaying)")
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
            
            // Arrow keys by keycode (characters are OS-specific escape codes)
            switch event.keyCode {
            case 123:
                store.goToPrevious()
                return nil
            case 124:
                store.goToNext()
                return nil
            default:
                return event
            }
        }
    }
    
    // MARK: - Main Image Display
    
    @ViewBuilder
    private var mainImageSection: some View {
        GeometryReader { geo in
            if let info = store.currentImage, let nsImage = loadImage(info) {
                let pixelSize = nsImage.pixelSize
                ZStack {
                    // Image always fits its viewer; only the viewer size changes with '0'
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(info.rotation))
                        .frame(width: geo.size.width, height: geo.size.height)
                    
                    // Mode badge so the change is always visible
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(store.isFitToWindow
                                 ? "FIT VIEWER • FULL SCREEN"
                                 : "NORMAL VIEWER • 1/3 SCREEN")
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(12)
                        }
                    }
                }
            } else {
                emptyState
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.loadImages(from: urls)
            return true
        }
    }
    
    // MARK: - Controls Bar
    
    private var controlsBar: some View {
        HStack(spacing: 16) {
            Button("◀ Prev") {
                store.goToPrevious()
            }
            
            Button(store.isSlideshowPlaying ? "⏸ Pause" : "▶ Play") {
                store.toggleSlideshow()
            }
            
            Button("Next ▶") {
                store.goToNext()
            }
            
            Spacer()
            
            Button("↺") {
                store.rotateCounterClockwise()
            }
            Button("↻") {
                store.rotateClockwise()
            }
            
            Button(store.isFitToWindow ? "1:1" : "Fit") {
                store.toggleFitToWindow()
            }
            
            Button("☰") {
                sidebarVisible.toggle()
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
        .opacity(isControlsVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isControlsVisible)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Drop images here or press 'o' to open")
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Supports PNG, JPG, HEIC, GIF, and more")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
            
            Text("Shortcuts: o=open, p=sidebar, ←→=navigate, ]/[=rotate, 0=normal/fit")
                .font(.caption)
                .foregroundColor(.white.opacity(0.2))
        }
    }
    
    // MARK: - Phase Indicator (Testing)
    
    private var phaseIndicator: some View {
        Text("Phase 1: Core Display")
            .font(.caption)
            .padding(4)
            .background(Color.orange.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
            .padding()
    }
    
    // MARK: - Helpers
    
    private func loadImage(_ info: ImageInfo) -> NSImage? {
        NSImage(contentsOf: info.url)
    }
}

extension NSImage {
    /// True pixel dimensions (respects Retina representations)
    var pixelSize: NSSize {
        guard let rep = representations.first else { return size }
        return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}
