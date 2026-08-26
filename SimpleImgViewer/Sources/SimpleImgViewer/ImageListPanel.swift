import SwiftUI

/// Right-side settings panel — slide timing, random mode, file loading
struct SettingsPanel: View {
    @ObservedObject var store: ImageStore
    @Binding var showOpenPanel: Bool
    @StateObject private var detector = OrientationDetector()
    @State private var timingText: String = "2.0"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider()
            
            // Slide timing
            VStack(alignment: .leading, spacing: 8) {
                Text("Slide interval (seconds)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("2.0", text: $timingText, onCommit: commitTiming)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 100)
                    .onSubmit(commitTiming)
                
                if let val = Double(timingText), val >= 0.1 {
                    Text("next slide in \(String(format: "%.1f", val))s")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                } else {
                    Text("min 0.1s")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            // Random mode
            Toggle(isOn: $store.randomMode) {
                Text("Random play")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .toggleStyle(.checkbox)
            
            Divider()
            
            // Auto-orientate scan
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    detector.scanAll(images: store.images, store: store)
                } label: {
                    HStack(spacing: 6) {
                        if detector.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(detector.isScanning ? "Scanning…" : "Auto-orientate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(store.images.isEmpty || detector.isScanning)
                
                if detector.isScanning {
                    ProgressView(value: detector.progress)
                    
                    let done = Int((detector.progress * Double(store.images.count)).rounded())
                    Text("\(done)/\(store.images.count)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .monospacedDigit()
                }
            }
            
            Divider()
            
            // File actions
            Button {
                showOpenPanel = true
            } label: {
                Label("Add images…", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            
            Spacer()
            
            Text("Shortcuts\no open · p carousel · s settings\n←→ navigate · [ ] rotate\n0 viewer size · Space slideshow")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.35))
                .lineSpacing(3)
        }
        .padding(20)
        .frame(width: 240)
        .frame(maxHeight: .infinity)
        .background(
            Color.black.opacity(0.88)
                .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1), alignment: .leading)
        )
    }
    
    private func commitTiming() {
        if let val = Double(timingText), val >= 0.1 {
            store.slideshowInterval = min(val, 3600)
            timingText = String(format: "%.1f", store.slideshowInterval)
        } else {
            timingText = String(format: "%.1f", store.slideshowInterval)
        }
    }
}

/// Bottom carousel of thumbnails; highlighted thumbnail always kept centered
struct ThumbnailCarousel: View {
    @ObservedObject var store: ImageStore
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.images.indices, id: \.self) { index in
                            ThumbnailCell(
                                info: store.images[index],
                                isSelected: index == store.currentIndex
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    store.currentIndex = index
                                }
                            }
                        }
                    }
                    // Half-viewport side insets let first/last thumbnails reach mid-carousel
                    .padding(.horizontal, max(geo.size.width / 2 - 36, 16))
                    .padding(.vertical, 12)
                }
                .background(
                    Color.black.opacity(0.85)
                        .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1), alignment: .top)
                )
                .onChange(of: store.currentIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(store.currentIndex, anchor: .center)
                }
            }
        }
        .frame(height: 96)
    }
}

struct ThumbnailCell: View {
    let info: ImageInfo
    let isSelected: Bool
    
    var body: some View {
        Group {
            if let nsImage = NSImage(contentsOf: info.url),
               let rep = nsImage.representations.first,
               rep.pixelsWide > 0, rep.pixelsHigh > 0 {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .overlay(alignment: .bottomLeading) {
            if info.orientation != .unknown {
                HStack(spacing: 2) {
                    Image(systemName: info.orientation.icon)
                        .font(.system(size: 7, weight: .bold))
                    Text(info.orientation.rawValue.prefix(4).capitalized)
                        .font(.system(size: 7, weight: .semibold))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(3)
                .padding(3)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.orange : Color.white.opacity(0.15),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .cornerRadius(8)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
