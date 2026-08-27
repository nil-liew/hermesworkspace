import SwiftUI

/// Right-side settings panel — slide timing, random mode, file loading
struct SettingsPanel: View {
    @ObservedObject var store: ImageStore
    @Binding var showOpenPanel: Bool
    @StateObject private var detector = OrientationDetector()
    @State private var timingText: String = "2.0"
    @Binding var showCheatsheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Slide interval (seconds)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("2.0", text: $timingText, onCommit: commitTiming)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 100)
                    .onSubmit(commitTiming)
            }
            
            Toggle(isOn: $store.randomMode) {
                Text("Random play")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .toggleStyle(.checkbox)
            
            Divider()
            
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
            
            Button {
                showOpenPanel = true
            } label: {
                Label("Add images…", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                Spacer()
                Button {
                    showCheatsheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Show all shortcuts")
            }
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

/// Full shortcuts cheatsheet
struct ShortcutsCheatsheet: View {
    private struct Row: Identifiable {
        let id = UUID()
        let keys: String
        let action: String
    }
    
    private let rows: [Row] = [
        .init(keys: "o", action: "Open images"),
        .init(keys: "c", action: "Toggle carousel panel"),
        .init(keys: "s", action: "Toggle settings panel"),
        .init(keys: "v", action: "Voice commands (next / previous)"),
        .init(keys: "← / →", action: "Previous / next image"),
        .init(keys: "[ / ]", action: "Rotate CCW / CW (saves to file)"),
        .init(keys: "0", action: "Viewer size: ½ screen ↔ full screen"),
        .init(keys: "Space", action: "Slideshow play/pause"),
        .init(keys: "z", action: "Zoom cycle 1× → 2× → 4× at cursor"),
    ]
    
    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 12) {
            Text(row.keys)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.77, blue: 0.5))
                .frame(width: 130, alignment: .trailing)
            Text(row.action)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard Shortcuts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 10)
            Divider()
                .overlay(Color.white.opacity(0.15))
            VStack(alignment: .leading, spacing: 7) {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            Text("press s or click ⓘ to close")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))
                .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15))
        )
        .shadow(radius: 20)
        .padding(30)
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
                                isSelected: index == store.currentIndex,
                                isInSelection: store.selectedIndices.contains(index)
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    let flags = NSEvent.modifierFlags
                                    if flags.contains(.shift) {
                                        store.shiftSelect(index: index)
                                    } else {
                                        store.clickSelect(index: index)
                                    }
                                }
                            }
                        }
                    }
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
    var isInSelection: Bool = false
    
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
                    (isSelected || isInSelection) ? Color.orange : Color.white.opacity(0.15),
                    lineWidth: (isSelected || isInSelection) ? 3 : 1
                )
        )
        .cornerRadius(8)
        .scaleEffect(isSelected ? 1.06 : (isInSelection ? 1.02 : 1.0))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isInSelection)
    }
}
