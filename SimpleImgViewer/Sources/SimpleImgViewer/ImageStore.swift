import SwiftUI
import ImageIO

/// ViewModel managing the image viewer state
class ImageStore: ObservableObject {
    @Published var images: [ImageInfo] = []
    @Published var currentIndex: Int = 0
    @Published var isFitToWindow: Bool = true
    @Published var isSlideshowPlaying: Bool = false
    @Published var carouselVisible: Bool = false
    /// Right-side settings panel visibility ('s')
    @Published var settingsVisible: Bool = false
    /// Auto-orientation scan results applied via setOrientation
    private(set) var orientationMap: [UUID: Orientation] = [:]
    /// Random (shuffle) slideshow mode
    @Published var randomMode: Bool = false
    
    // MARK: - Zoom state ('z' toggles 2x at cursor)
    @Published var zoomScale: Double = 1.0
    @Published var zoomOffset: CGSize = .zero
    let defaultZoomScale: Double = 2.0
    
    func setZoom(_ scale: Double, offsetX: Double, offsetY: Double) {
        zoomScale = scale
        zoomOffset = CGSize(width: offsetX, height: offsetY)
    }
    
    func resetZoom() {
        zoomScale = 1.0
        zoomOffset = .zero
    }
    
    private var slideshowTimer: Timer?
    /// Slideshow interval in seconds; user-editable to one decimal in the controls bar
    var slideshowInterval: Double = 2.0
    
    var currentImage: ImageInfo? {
        images.indices.contains(currentIndex) ? images[currentIndex] : nil
    }
    
    func loadImages(from urls: [URL]) {
        let newImages = urls.map { ImageInfo(url: $0, rotation: 0.0) }
        guard !newImages.isEmpty else { return }
        let firstNewIndex = images.count
        images.append(contentsOf: newImages)
        // Jump to first newly added image so the drop is visibly acknowledged
        currentIndex = firstNewIndex
        // Show carousel automatically once images are loaded
        if !carouselVisible { carouselVisible = true }
    }
    
    func goToNext() {
        guard !images.isEmpty else { return }
        if randomMode && isSlideshowPlaying {
            currentIndex = randomIndex(excluding: currentIndex)
        } else {
            currentIndex = (currentIndex + 1) % images.count
        }
    }
    
    func goToPrevious() {
        guard !images.isEmpty else { return }
        if randomMode && isSlideshowPlaying {
            currentIndex = randomIndex(excluding: currentIndex)
        } else {
            currentIndex = (currentIndex - 1 + images.count) % images.count
        }
    }
    
    /// Random index in 0..<count that differs from `excluding`
    private func randomIndex(excluding: Int) -> Int {
        guard images.count > 1 else { return excluding }
        var value = Int.random(in: 0..<images.count)
        if value == excluding {
            value = (value + 1) % images.count
        }
        return value
    }
    
    /// Apply detected orientation + corrective rotation for a given image
    func setOrientation(id: UUID, orientation: Orientation, rotationDegrees: Double = 0) {
        orientationMap[id] = orientation
        if let idx = images.firstIndex(where: { $0.id == id }) {
            images[idx].orientation = orientation
            images[idx].rotation = rotationDegrees
        }
        objectWillChange.send()
    }
    
    func toggleFitToWindow() {
        isFitToWindow.toggle()
        DispatchQueue.main.async { self.applyWindowMode() }
    }
    
    /// Normal = window at ~1/3 of screen, centered. Fit = fullscreen.
    private func applyWindowMode() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && !$0.isSheet }) else { return }
        
        if isFitToWindow {
            if let screen = window.screen ?? NSScreen.main {
                window.setFrame(screen.visibleFrame, display: true, animate: true)
            }
        } else {
            guard let screen = window.screen ?? NSScreen.main else { return }
            let half = CGSize(width: screen.frame.width / 2,
                               height: screen.frame.height / 2)
            var frame = NSRect(origin: .zero, size: half)
            frame.origin.x = screen.frame.midX - half.width / 2
            frame.origin.y = screen.frame.midY - half.height / 2
            window.setFrame(frame, display: true, animate: true)
        }
    }
    
    func rotateClockwise() {
        guard images.indices.contains(currentIndex) else { return }
        let url = images[currentIndex].url
        // Persist to source file (static images only); reset viewer rotation since
        // the file itself is now rotated
        FileRotator.rotateFile(at: url, clockwise: true)
        images[currentIndex].rotation = 0
        objectWillChange.send()
    }
    
    func rotateCounterClockwise() {
        guard images.indices.contains(currentIndex) else { return }
        let url = images[currentIndex].url
        FileRotator.rotateFile(at: url, clockwise: false)
        images[currentIndex].rotation = 0
        objectWillChange.send()
    }
    
    // MARK: - Slideshow
    
    func toggleSlideshow() {
        isSlideshowPlaying ? stopSlideshow() : startSlideshow()
    }
    
    func startSlideshow() {
        guard !images.isEmpty else { return }
        isSlideshowPlaying = true
        scheduleNextSlide()
    }
    
    func stopSlideshow() {
        isSlideshowPlaying = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
    
    private func scheduleNextSlide() {
        slideshowTimer?.invalidate()
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: slideshowInterval, repeats: false) { [weak self] _ in
            guard let self, self.isSlideshowPlaying else { return }
            
            if self.randomMode {
                self.currentIndex = self.randomIndex(excluding: self.currentIndex)
            } else {
                self.goToNext()
            }
            self.scheduleNextSlide()
        }
    }
}

enum Orientation: String, Codable {
    case portrait, landscape, square, unknown
    
    var icon: String {
        switch self {
        case .portrait: return "iphone"
        case .landscape: return "laptopcomputer"
        case .square: return "square.dashed"
        case .unknown: return "questionmark.square.dashed"
        }
    }
    
    var label: String { rawValue.capitalized }
}

struct ImageInfo: Identifiable {
    let id = UUID()
    let url: URL
    var rotation: Double
    var orientation: Orientation = .unknown
    
    /// True if the file has multiple frames (animated GIF / animated WebP)
    static func isAnimated(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ext == "gif" || ext == "webp" else { return false }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return CGImageSourceGetCount(source) > 1
    }
}
