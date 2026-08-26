import SwiftUI
import AppKit
import ImageIO

/// NSView that plays animated GIFs and animated WebP via ImageIO frame rendering.
final class AnimatedImageView: NSView {
    private var imageSource: CGImageSource?
    private var frames: [CGImage] = []
    private var frameDurations: [Double] = []
    private var imageView = NSImageView()
    private var timer: Timer?
    private var currentFrame = 0
    
    /// Rotation in degrees applied on top of the rendered animation
    var rotationDegrees: Double = 0 {
        didSet { imageView.frameRotation = CGFloat(rotationDegrees) }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.animates = false
        addSubview(imageView)
    }
    
    /// Load an image file; returns true if it is animated and playback started.
    @discardableResult
    func load(url: URL) -> Bool {
        stop()
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 1 else {
            return false // static image — let SwiftUI handle it
        }
        
        imageSource = source
        let count = CGImageSourceGetCount(source)
        frames.removeAll()
        frameDurations.removeAll()
        
        for i in 0..<count {
            if let img = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(img)
                frameDurations.append(Self.frameDuration(source: source, index: i))
            }
        }
        
        guard !frames.isEmpty else { return false }
        currentFrame = 0
        showCurrentFrame()
        scheduleNext()
        return true
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        frames.removeAll()
        frameDurations.removeAll()
        imageSource = nil
        currentFrame = 0
    }
    
    private func showCurrentFrame() {
        guard frames.indices.contains(currentFrame) else { return }
        imageView.image = NSImage(cgImage: frames[currentFrame], size: .zero)
        needsLayout = true
    }
    
    private func scheduleNext() {
        let duration = frameDurations.indices.contains(currentFrame) ? frameDurations[currentFrame] : 0.1
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentFrame = (self.currentFrame + 1) % self.frames.count
            self.showCurrentFrame()
            self.scheduleNext()
        }
    }
    
    override func layout() {
        super.layout()
        // Fit frame to view while preserving aspect ratio
        imageView.frame = bounds
    }
    
    /// Per-frame duration honoring GIF/WebP delay metadata (min 0.02s)
    private static func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.1
        }
        let gifInfo = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let webpInfo = props[kCGImagePropertyWebPDictionary] as? [CFString: Any]
        guard let info = gifInfo ?? webpInfo else { return 0.1 }
        let unclamped = info[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = info[kCGImagePropertyGIFDelayTime] as? Double
        return max(unclamped ?? clamped ?? 0.1, 0.02)
    }
}

/// SwiftUI wrapper for the animated image view
struct AnimatedImagePlayerView: NSViewRepresentable {
    let url: URL
    let rotation: Double
    
    func makeNSView(context: Context) -> AnimatedImageView {
        let view = AnimatedImageView(frame: .zero)
        return view
    }
    
    func updateNSView(_ nsView: AnimatedImageView, context: Context) {
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            nsView.load(url: url)
        }
        nsView.rotationDegrees = rotation
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator {
        var loadedURL: URL?
    }
}
