import SwiftUI

/// ViewModel managing the image viewer state
class ImageStore: ObservableObject {
    @Published var images: [ImageInfo] = []
    @Published var currentIndex: Int = 0
    @Published var isFitToWindow: Bool = true
    @Published var isSlideshowPlaying: Bool = false
    
    private var slideshowTimer: Timer?
    /// Slideshow interval in seconds (user-adjustable up to one decimal in Phase 3 UI)
    var slideshowInterval: Double = 2.0
    
    var currentImage: ImageInfo? {
        images.indices.contains(currentIndex) ? images[currentIndex] : nil
    }
    
    func loadImages(from urls: [URL]) {
        let newImages = urls.map { ImageInfo(url: $0, rotation: 0.0) }
        images.append(contentsOf: newImages)
        if images.count == newImages.count {
            currentIndex = 0
        }
    }
    
    func goToNext() {
        guard !images.isEmpty else { return }
        currentIndex = (currentIndex + 1) % images.count
    }
    
    func goToPrevious() {
        guard !images.isEmpty else { return }
        currentIndex = (currentIndex - 1 + images.count) % images.count
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
            let third = CGSize(width: screen.frame.width / 3,
                               height: screen.frame.height / 3)
            var frame = NSRect(origin: .zero, size: third)
            // Center on screen
            frame.origin.x = screen.frame.midX - third.width / 2
            frame.origin.y = screen.frame.midY - third.height / 2
            window.setFrame(frame, display: true, animate: true)
        }
    }
    
    func rotateClockwise() {
        guard images.indices.contains(currentIndex) else { return }
        images[currentIndex].rotation = (images[currentIndex].rotation + 90).truncatingRemainder(dividingBy: 360)
    }
    
    func rotateCounterClockwise() {
        guard images.indices.contains(currentIndex) else { return }
        images[currentIndex].rotation = (images[currentIndex].rotation - 90 + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - Slideshow (basic; timing input UI comes in Phase 3)
    
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
            self.goToNext()
            self.scheduleNextSlide()
        }
    }
}

struct ImageInfo: Identifiable {
    let id = UUID()
    let url: URL
    var rotation: Double
}
