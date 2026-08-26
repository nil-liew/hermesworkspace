import SwiftUI
import AppKit
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Persists rotation to the source file, Preview-style:
/// - 90° pixel transform (JPEG re-encode is visually lossless for screenshots;
///   PNG/BMP are lossless formats)
/// - Animated files (GIF/WebP with multiple frames) are skipped to preserve animation
enum FileRotator {
    /// Backup folder for originals before first modification
    static var backupDir: URL {
        let url = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SIV-Originals", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    /// Rotate the file at `url` by ±90° and overwrite in place.
    @discardableResult
    static func rotateFile(at url: URL, clockwise: Bool) -> Bool {
        // Skip animated images — rotating would freeze animation
        if ImageInfo.isAnimated(url) { return false }
        
        backupOriginalIfNeeded(url)
        
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let source = CGImageSourceCreateWithData(tiff as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        
        guard let rotatedCG = rotateByDrawing(image: cgImage, clockwise: clockwise) else { return false }
        
        let ext = url.pathExtension.lowercased()
        let uttype: UTType
        switch ext {
        case "jpeg", "jpg": uttype = .jpeg
        case "png": uttype = .png
        case "bmp": uttype = .bmp
        case "tiff", "tif": uttype = .tiff
        default: return false
        }
        
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                         uttype.identifier as CFString,
                                                         1, nil) else { return false }
        // Fresh encode carries no EXIF orientation → no double-rotation elsewhere
        CGImageDestinationAddImage(dest, rotatedCG, nil)
        let ok = CGImageDestinationFinalize(dest)
        
        if ok { backupOriginalIfNeeded(url) }
        return ok
    }
    
    private static func rotateByDrawing(image: CGImage, clockwise: Bool) -> CGImage? {
        let swap = true // ±90° always swaps dimensions
        let w = swap ? image.height : image.width
        let h = swap ? image.width : image.height
        
        guard let context = CGContext(data: nil,
                                      width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        
        context.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
        context.rotate(by: (clockwise ? -90 : 90) * .pi / 180) // CG y-axis is flipped
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2,
                                       y: -CGFloat(image.height) / 2,
                                       width: CGFloat(image.width),
                                       height: CGFloat(image.height)))
        return context.makeImage()
    }
    
    /// Copy original to backup dir once per filename; later rotations skip (already backed up)
    private static func backupOriginalIfNeeded(_ url: URL) {
        let fm = FileManager.default
        let dest = backupDir.appendingPathComponent(url.lastPathComponent)
        guard !fm.fileExists(atPath: dest.path) else { return }
        try? fm.copyItem(at: url, to: dest)
    }
}
