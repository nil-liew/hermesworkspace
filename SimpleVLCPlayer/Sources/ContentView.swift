import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var player = PlayerModel()
    @State private var showFilePicker = false
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            VideoArea
            
            controlsBar
                .padding(.vertical, 8)
                .background(cinemaDarkSurface)
        }
        .frame(minWidth: 640, minHeight: 480, maxHeight: 900)
        .background(cinemaDarkBg)
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: .openFile,
                object: nil,
                queue: .main
            ) { notification in
                if let url = notification.userInfo?["url"] as? URL {
                    player.open(url: url)
                } else {
                    showFilePicker = true
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                player.open(url: url)
            }
        }
    }
    
    private var VideoArea: some View {
        ZStack {
            if player.url != nil {
                VideoView(player: player)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(cinemaPastelBlue.opacity(0.6))
            Text("Open a video to begin")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("File → Open or press ⌘O")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var controlsBar: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            Divider()
                .background(cinemaBorder)
            
            // Controls row
            HStack(spacing: 16) {
                // Left side: rewind buttons
                skipButton(symbol: "gobackward.15", label: "–15s", action: { player.step(-15) })
                
                Spacer()
                
                // Center: play/pause
                playPauseButton
                
                Spacer()
                
                // Right side: forward buttons
                skipButton(symbol: "goforward.15", label: "+15s", action: { player.step(15) })
                
                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)
                
                // Rotation buttons
                rotateButton(symbol: "arrow.uturn.backward.circle", action: { player.rotate(-90) })
                rotateButton(symbol: "arrow.uturn.forward.circle", action: { player.rotate(90) })
            }
            .font(.title3)
            .foregroundColor(cinemaTextPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(cinemaDarkSurface)
    }
    
    private var progressBar: some View {
        VStack(spacing: 4) {
            // Seekable progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(cinemaBorder)
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Played portion
                    if let duration = player.duration, duration > 0 {
                        Rectangle()
                            .fill(cinemaPastelBlue)
                            .frame(
                                width: geo.size.width * min(player.currentTime / duration, 1.0),
                                height: 4
                            )
                            .cornerRadius(2)
                    }
                    
                    // Thumb
                    if let duration = player.duration, duration > 0 {
                        Circle()
                            .fill(cinemaPastelPink)
                            .frame(width: 12, height: 12)
                            .offset(x: geo.size.width * min(player.currentTime / duration, 1.0) - 6)
                            .opacity(player.isSeeking ? 1 : 0)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            player.startSeeking()
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / geo.size.width))
                            player.seek(to: ratio)
                            player.stopSeeking()
                        }
                )
            }
            .frame(height: 12)
            
            // Time labels
            HStack {
                Text(player.formatTime(player.currentTime))
                    .font(.caption2)
                    .foregroundColor(cinemaTextSecondary)
                
                Spacer()
                
                if let duration = player.duration {
                    Text(player.formatTime(duration))
                        .font(.caption2)
                        .foregroundColor(cinemaTextSecondary)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func skipButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.body)
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 40, height: 40)
            .background(cinemaButtonBg.opacity(0.8))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(cinemaTextPrimary)
    }

    private var playPauseButton: some View {
        Button(action: { player.togglePlay() }) {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(cinemaPastelPink)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .shadow(color: cinemaPastelPink.opacity(0.4), radius: 4)
    }

    private func rotateButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
                .background(cinemaButtonBg.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

func URLSupportsVideo(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "mpeg", "mpg", "webm", "wmv", "flv"]
    return videoExtensions.contains(ext)
}
