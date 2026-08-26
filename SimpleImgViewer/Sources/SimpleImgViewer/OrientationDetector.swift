import SwiftUI
import Vision
import AppKit

/// Auto-orientation detection: scans image content with Vision saliency to
/// decide whether the subject reads as portrait or landscape, falling back to
/// the image's own aspect ratio.
final class OrientationDetector: ObservableObject {
    @Published var progress: Double = 0
    @Published var isScanning = false
    
    /// Scan all images and set orientation + corrective rotation.
    /// Runs on a background queue.
    func scanAll(images: [ImageInfo], store: ImageStore) {
        guard !isScanning else { return }
        isScanning = true
        progress = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            let total = max(images.count, 1)
            for (i, info) in images.enumerated() {
                let orientation = Self.detect(url: info.url)
                // Corrective rotation so the subject displays upright:
                // portrait subject in a landscape frame -> rotate 90°, and vice versa.
                let rotation = Self.correctionDegrees(current: info.rotation,
                                                      orientation: orientation,
                                                      url: info.url)
                DispatchQueue.main.async {
                    store.setOrientation(id: info.id,
                                         orientation: orientation,
                                         rotationDegrees: rotation)
                    self.progress = Double(i + 1) / Double(total)
                    if i + 1 == total {
                        self.isScanning = false
                    }
                }
            }
        }
    }
    
    /// Rotation needed so a detected portrait/landscape subject appears upright.
    /// - If the image's displayed aspect already matches the subject orientation → 0
    /// - Portrait subject in landscape frame → rotate 90° (CW)
    /// - Landscape subject in portrait frame → rotate 270° (-90°)
    static func correctionDegrees(current: Double, orientation: Orientation, url: URL) -> Double {
        guard orientation == .portrait || orientation == .landscape,
              let img = NSImage(contentsOf: url), let rep = img.representations.first else { return current }
        
        // Displayed aspect (NSImage applies EXIF automatically)
        let w = CGFloat(rep.pixelsWide)
        let h = CGFloat(rep.pixelsHigh)
        let displayedIsLandscape = w > h
        let displayedIsPortrait = h > w
        
        switch orientation {
        case .portrait:
            if displayedIsLandscape { return normalize(current, target: 90) }   // tip it upright
        case .landscape:
            if displayedIsPortrait { return normalize(current, target: 270) }   // lay it on its side
        default:
            break
        }
        return current
    }
    
    /// Keep manual rotations: add the corrective delta to what the user had set
    private static func normalize(_ current: Double, target: Double) -> Double {
        let total = (current + target).truncatingRemainder(dividingBy: 360)
        return total < 0 ? total + 360 : total
    }
    
    /// Subject-based detection via Vision saliency; falls back to aspect ratio.
    static func detect(url: URL) -> Orientation {
        guard let ciImage = CIImage(contentsOf: url) else { return .unknown }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        
        if (try? handler.perform([request])) != nil,
           let results = request.results as? [VNSaliencyImageObservation],
           let salientObjects = results.first?.salientObjects, !salientObjects.isEmpty {
            // Average bounding box of salient subjects determines subject shape
            let avgW = salientObjects.map { $0.boundingBox.width }.reduce(CGFloat(0), +) / CGFloat(salientObjects.count)
            let avgH = salientObjects.map { $0.boundingBox.height }.reduce(CGFloat(0), +) / CGFloat(salientObjects.count)
            if avgW > avgH * 1.05 { return .landscape }
            if avgH > avgW * 1.05 { return .portrait }
            return .square
        }
        
        // Fallback: whole-image aspect ratio
        let w = ciImage.extent.width
        let h = ciImage.extent.height
        if w > h * 1.05 { return .landscape }
        if h > w * 1.05 { return .portrait }
        return .square
    }
}
