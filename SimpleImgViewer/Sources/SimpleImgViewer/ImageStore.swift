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
    /// Random (shuffle) slideshow mode
    @Published var randomMode: Bool = false
    /// Carousel multi-selection (shift-click range) for batch rotation
    @Published var selectedIndices: Set<Int> = []
    /// Anchor for shift-click range selection
    var shiftAnchor: Int = 0
    
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
        selectedIndices = [firstNewIndex]
        shiftAnchor = firstNewIndex
        // Show carousel automatically once images are loaded
        if !carouselVisible { carouselVisible = true }
    }
    
    /// Shift-click: select the contiguous range between anchor and clicked index.
    func shiftSelect(index: Int) {
        guard images.indices.contains(index) else { return }
        let lo = min(shiftAnchor, index)
        let hi = max(shiftAnchor, index)
        selectedIndices = Set(lo...hi)
        objectWillChange.send()
    }

    /// Select all images in the carousel
    func selectAll() {
        guard !images.isEmpty else { return }
        selectedIndices = Set(images.indices)
        objectWillChange.send()
    }
    
    /// Plain click: single selection, also navigates viewer to that image
    func clickSelect(index: Int) {
        guard images.indices.contains(index) else { return }
        currentIndex = index
        selectedIndices = [index]
        shiftAnchor = index
        objectWillChange.send()
    }
    
    func goToNext(shift: Bool = false) {
        guard !images.isEmpty else { return }
        if shift && !selectedIndices.isEmpty {
            // Shift+arrow: extend selection to next image (keep anchor, add new)
            let nextIdx = (currentIndex + 1) % images.count
            shiftSelect(index: nextIdx)
            currentIndex = nextIdx
        } else {
            // Normal navigation: clear selection first, then move
            currentIndex = (currentIndex + 1) % images.count
            selectedIndices = [currentIndex]
            shiftAnchor = currentIndex
        }
    }

    func goToPrevious(shift: Bool = false) {
        guard !images.isEmpty else { return }
        if shift && !selectedIndices.isEmpty {
            // Shift+arrow: extend selection to previous image (keep anchor, add new)
            let prevIdx = (currentIndex - 1 + images.count) % images.count
            shiftSelect(index: prevIdx)
            currentIndex = prevIdx
        } else {
            // Normal navigation: clear selection first, then move
            currentIndex = (currentIndex - 1 + images.count) % images.count
            selectedIndices = [currentIndex]
            shiftAnchor = currentIndex
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
    
    /// Indices to rotate: multi-selection if any, else current image
    private var rotationTargets: [Int] {
        selectedIndices.filter { images.indices.contains($0) }.sorted()
    }
    
    func rotateClockwise() {
        let targets = rotationTargets
        guard !targets.isEmpty else { return }
        for idx in targets {
            FileRotator.rotateFile(at: images[idx].url, clockwise: true)
            images[idx].rotation = 0
        }
        objectWillChange.send()
    }
    
    func rotateCounterClockwise() {
        let targets = rotationTargets
        guard !targets.isEmpty else { return }
        for idx in targets {
            FileRotator.rotateFile(at: images[idx].url, clockwise: false)
            images[idx].rotation = 0
        }
        objectWillChange.send()
    }
    
    // MARK: - Remove images

    /// Remove selected images from the list only (keeps source files)
    func removeSelected() {
        guard !selectedIndices.isEmpty else { return }
        let indicesToRemove = Array(selectedIndices).sorted(by: >)
        for idx in indicesToRemove {
            if idx == currentIndex {
                currentIndex = max(0, currentIndex - 1)
            } else if idx < currentIndex {
                currentIndex -= 1
            }
        }
        images.remove(atOffsets: IndexSet(indicesToRemove))
        selectedIndices = currentIndex >= 0 && currentIndex < images.count ? [currentIndex] : []
        shiftAnchor = currentIndex
        objectWillChange.send()
    }

    /// Remove selected images and delete source files from disk
    func removeSelectedAndDelete() {
        guard !selectedIndices.isEmpty else { return }
        let indicesToRemove = Array(selectedIndices).sorted()
        for idx in indicesToRemove {
            try? FileManager.default.removeItem(at: images[idx].url)
        }
        removeSelected()
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
    
    /// True if the file has multiple frames (animated GIF / animated WebP)
    static func isAnimated(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ext == "gif" || ext == "webp" else { return false }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return CGImageSourceGetCount(source) > 1
    }
}
