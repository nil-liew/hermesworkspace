import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Main content view — minimal chrome: no buttons, keyboard-driven.
/// 's' toggles a settings panel on the right; 'p' toggles bottom carousel.
struct ContentView: View {
    @StateObject private var store = ImageStore()
    @StateObject private var voice = VoiceController()
    @State private var showOpenPanel = false
    @State private var showCheatsheet = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 0) {
                        // Main image display (AppKit-level drop zone for reliable repeat drops)
                        FileDropZone(onDrop: { urls in
                            print("[SIV] loadImages called with \(urls.count)")
                            store.loadImages(from: urls)
                        }) {
                            mainImageSection
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Bottom thumbnail carousel (toggled with 'p')
                        if store.carouselVisible {
                            ThumbnailCarousel(store: store)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    
                    // Cheatsheet overlays ONLY the viewer area — settings panel stays fully visible
                    if showCheatsheet {
                        ZStack {
                            Color.black.opacity(0.55)
                                .onTapGesture { showCheatsheet = false }
                            
                            ShortcutsCheatsheet()
                                .transition(.opacity)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right settings panel (toggled with 's')
                if store.settingsVisible {
                    SettingsPanel(store: store, showOpenPanel: $showOpenPanel, showCheatsheet: $showCheatsheet)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            phaseIndicator
        }
        .overlay(alignment: .topTrailing) {
            // Voice status badge (top-right, above slideshow badge)
            if voice.isListening {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(voice.statusText.isEmpty ? "Listening…" : voice.statusText)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.75))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 10) {
                if store.isSlideshowPlaying {
                    HStack(spacing: 5) {
                        Image(systemName: store.randomMode ? "dice" : "play.fill")
                            .font(.system(size: 9))
                        Text("\(String(format: "%.1f", store.slideshowInterval))s \(store.randomMode ? "random" : "")")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.8))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
                
                Text(voice.statusText)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
            }
            .padding(.trailing, store.settingsVisible ? 264 : 16)
        }
        .animation(.easeInOut(duration: 0.25), value: store.carouselVisible)
        .animation(.easeInOut(duration: 0.25), value: store.settingsVisible)
        .fileImporter(
            isPresented: $showOpenPanel,
            allowedContentTypes: [.png, .jpeg, .heic, .heif, .tiff, .bmp, .gif,
                                   UTType(filenameExtension: "webp") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                store.loadImages(from: urls)
            case .failure: break
            }
        }
        .onAppear {
            setupKeyboardMonitor()
            voice.onNext = { store.goToNext() }
            voice.onPrevious = { store.goToPrevious() }
        }
    }
    
    // MARK: - Keyboard Event Monitor (character-based matching)
    
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                return event
            }
            
            if let chars = event.charactersIgnoringModifiers?.lowercased(), chars.count == 1 {
                switch chars {
                case "o":
                    showOpenPanel = true
                    return nil
                case "c":
                    store.carouselVisible.toggle()
                    return nil
                case "s":
                    store.settingsVisible.toggle()
                    return nil
                case "v":
                    voice.toggle()
                    return nil
                case "i":
                    showCheatsheet.toggle()
                    return nil
                case "z":
                    toggleZoomAtCursor()
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
            let zoomed = store.zoomScale > 1.0
            Group {
                if let info = store.currentImage {
                    if ImageInfo.isAnimated(info.url) {
                        // Animated GIF / animated WebP playback via ImageIO
                        AnimatedImagePlayerView(url: info.url, rotation: info.rotation)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(store.zoomScale)
                            .offset(store.zoomOffset)
                            .clipped()
                    } else if let nsImage = loadImage(info) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(info.rotation))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(store.zoomScale)
                            .offset(store.zoomOffset)
                            .clipped()
                    } else {
                        emptyState
                    }
                } else {
                    emptyState
                }
            }
            .animation(.easeInOut(duration: 0.2), value: store.zoomScale)
        }
    }
    
    // MARK: - Zoom ('z' toggles 2x centered at cursor)
    
    private func toggleZoomAtCursor() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
        
        // Cursor position in window coordinates, top-left origin (matches SwiftUI)
        let mouse = NSEvent.mouseLocation
        let frame = window.frame
        let localX = mouse.x - frame.origin.x
        let localY = (frame.origin.y + frame.height) - mouse.y
        
        // Cycle zoom levels: 1x -> 2x -> 4x -> 1x
        let nextScale: Double
        switch store.zoomScale {
        case ..<1.5: nextScale = 2.0
        case ..<3.0: nextScale = 4.0
        default:     store.resetZoom(); return
        }
        
        // Offset from window center; keep the cursor point stationary under the scale
        let cx = frame.width / 2
        let cy = frame.height / 2
        let k = nextScale - 1.0
        store.setZoom(nextScale,
                      offsetX: -(localX - cx) * k,
                      offsetY: -(localY - cy) * k)
    }
    
    // MARK: - Slideshow Badge
    
    @ViewBuilder
    private var slideshowBadge: some View {
        if store.isSlideshowPlaying {
            HStack(spacing: 5) {
                Image(systemName: store.randomMode ? "dice" : "play.fill")
                    .font(.system(size: 9))
                Text("\(String(format: "%.1f", store.slideshowInterval))s \(store.randomMode ? "random" : "")")
                    .monospacedDigit()
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.8))
            .foregroundColor(.black)
            .cornerRadius(6)
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Drop images here to start")
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Supports PNG, JPG, HEIC, GIF, and more")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Phase Indicator (Testing)
    
    private var phaseIndicator: some View {
        Text("Phase 3b: Minimal UI + Settings Panel ('s')")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.8))
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
