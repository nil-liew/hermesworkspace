import SwiftUI

/// Collapsible sidebar showing image thumbnails
struct ImageListPanel: View {
    @ObservedObject var store: ImageStore
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Images (\(store.images.count))")
                .font(.headline)
                .padding()
                .background(Color.black.opacity(0.5))
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(store.images.indices, id: \.self) { index in
                        ThumbnailCell(
                            info: store.images[index],
                            isSelected: index == store.currentIndex
                        )
                        .onTapGesture {
                            store.currentIndex = index
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.black.opacity(0.8))
    }
}

struct ThumbnailCell: View {
    let info: ImageInfo
    let isSelected: Bool
    
    var body: some View {
        Group {
            if let nsImage = loadImage(info), let rep = nsImage.representations.first,
               rep.pixelsWide > 0, rep.pixelsHigh > 0 {
                // Preserve true pixel aspect ratio; crop to square cell
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isSelected ? Color.orange : Color.white.opacity(0.15),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .cornerRadius(4)
    }
    
    private func loadImage(_ info: ImageInfo) -> NSImage? {
        NSImage(contentsOf: info.url)
    }
}
