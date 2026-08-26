import SwiftUI

/// Right-side settings panel — slide timing, random mode, file loading
struct SettingsPanel: View {
    @ObservedObject var store: ImageStore
    @Binding var showOpenPanel: Bool
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

/// Bottom carousel of thumbnails; current selection highlighted and auto-scrolled
struct ThumbnailCarousel: View {
    @ObservedObject var store: ImageStore
    
    var body: some View {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                Color.black.opacity(0.85)
                    .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1), alignment: .top)
            )
            .frame(height: 96)
            .onChange(of: store.currentIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
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
