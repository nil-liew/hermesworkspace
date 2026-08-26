import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Main content view — minimal chrome: no buttons, keyboard-driven.
/// 's' toggles a settings panel on the right; 'p' toggles bottom carousel.
struct ContentView: View {
    @StateObject private var store = ImageStore()
    @State private var showOpenPanel = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Main image display
                    mainImageSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom thumbnail carousel (toggled with 'p')
                    if store.carouselVisible {
                        ThumbnailCarousel(store: store)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right settings panel (toggled with 's')
                if store.settingsVisible {
                    SettingsPanel(store: store, showOpenPanel: $showOpenPanel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            phaseIndicator
        }
        .overlay(alignment: .topTrailing) {
            slideshowBadge.padding(.trailing, store.settingsVisible ? 264 : 0)
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
                case "p":
                    store.carouselVisible.toggle()
                    return nil
                case "s":
                    store.settingsVisible.toggle()
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
            if let info = store.currentImage {
                if ImageInfo.isAnimated(info.url) {
                    // Animated GIF / animated WebP playback via ImageIO
                    AnimatedImagePlayerView(url: info.url, rotation: info.rotation)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else if let nsImage = loadImage(info) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(info.rotation))
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    emptyState
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
