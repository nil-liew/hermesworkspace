import AVKit
import SwiftUI
import CoreMedia

class PlayerModel: ObservableObject {
    @Published var isPlaying = false
    @Published var rotationDegrees: Double = 0
    @Published var currentTime: Double = 0
    @Published var duration: Double?
    @Published var isSeeking = false
    
    var player: AVPlayer?
    var url: URL?
    private var timeObserver: Any?
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }

    func open(url: URL) {
        self.url = url
        
        // Clean up old player
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        player?.pause()
        player = AVPlayer(url: url)
        
        // Observe time updates for progress bar
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if self.duration == nil {
                let cmDuration = self.player?.currentItem?.duration ?? CMTime.invalid
                if cmDuration.isValid && cmDuration.isNumeric {
                    self.duration = cmDuration.seconds
                }
            }
        }
        
        player?.play()
        isPlaying = true
    }

    func togglePlay() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func step(_ seconds: Double) {
        guard let player = player, player.currentItem != nil else { return }
        let delta = CMTime(seconds: seconds, preferredTimescale: 600)
        let newTime = CMTimeAdd(player.currentTime(), delta)
        player.seek(to: newTime)
    }
    
    func seek(to ratio: Double) {
        guard let duration = duration, duration > 0 else { return }
        let targetTime = CMTime(seconds: ratio * duration, preferredTimescale: 600)
        player?.seek(to: targetTime)
    }
    
    func startSeeking() {
        isSeeking = true
    }
    
    func stopSeeking() {
        isSeeking = false
    }

    func rotate(_ degrees: Double) {
        rotationDegrees = rotationDegrees + degrees
    }
    
    func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

struct VideoView: View {
    @ObservedObject var player: PlayerModel

    var body: some View {
        if let avPlayer = player.player {
            PlayerView(player: avPlayer)
                .ignoresSafeArea()
                .rotationEffect(.degrees(player.rotationDegrees))
                .animation(.easeInOut(duration: 0.3), value: player.rotationDegrees)
        } else {
            Color.black.ignoresSafeArea()
        }
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
