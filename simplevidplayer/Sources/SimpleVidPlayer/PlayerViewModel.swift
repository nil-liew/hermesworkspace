import SwiftUI
import VLCKit
import CoreTransferable

struct PlaylistItem: Identifiable, Equatable, Codable, Transferable {
    let id = UUID()
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

@MainActor
final class PlayerViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentURL: URL?
    @Published var playlist: [PlaylistItem] = []
    @Published var currentIndex: Int = -1
    // Published so views re-bind when the player is recreated per media load.
    @Published var player = VLCMediaPlayer(options: ["--no-video-title-show"])

    override init() {
        super.init()
        player.delegate = self
    }

    // MARK: - Playback

    func play(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        currentIndex = index
        load(playlist[index].url)
    }

    func load(_ url: URL) {
        currentURL = url
        currentTime = 0
        duration = 0
        isPlaying = false
        // VLCKit 4 bug: its OpenGL vout asserts (vout_display_opengl_Prepare) if
        // the old vout is still rendering when a new player attaches to the same
        // view. Detach + stop the old player, and only create/attach the fresh one
        // on the NEXT runloop turn so the old vout thread fully quiesces.
        let retiring = player
        retiring.delegate = nil
        retiring.drawable = nil
        retiring.stop()
        videoView?.needsDisplay = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let fresh = VLCMediaPlayer(options: ["--no-video-title-show"])
            fresh.media = VLCMedia(url: url)
            fresh.delegate = self
            self.player = fresh
            if let view = self.videoView {
                fresh.drawable = view
            }
            fresh.play()
        }
    }

    /// Weak ref to the drop/draw view so each new player can attach to it.
    weak var videoView: NSView?

    func togglePlay() {
        if player.state == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func playNext() {
        let next = currentIndex + 1
        if next < playlist.count {
            play(at: next)
        }
    }

    // MARK: - Playlist management

    /// Adds files to the playlist. If nothing is playing, starts the first added file.
    func addToPlaylistAndPlay(_ urls: [URL]) {
        let items = urls.map { PlaylistItem(url: $0) }
        let wasEmpty = currentIndex < 0
        playlist.append(contentsOf: items)
        if wasEmpty, !items.isEmpty {
            play(at: playlist.count - items.count)
        }
    }

    func addToPlaylist(_ urls: [URL]) {
        playlist.append(contentsOf: urls.map { PlaylistItem(url: $0) })
    }

    func removeFromPlaylist(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) {
            let wasCurrent = (i == currentIndex)
            let wasBefore = i < currentIndex
            playlist.remove(at: i)
            if wasCurrent {
                player.drawable = nil
                player.delegate = nil
                player.stop()
                let fresh = VLCMediaPlayer(options: ["--no-video-title-show"])
                fresh.delegate = self
                player = fresh
                currentIndex = -1
                currentURL = nil
                isPlaying = false
                currentTime = 0
                duration = 0
            } else if wasBefore {
                currentIndex -= 1
            }
        }
    }

    func movePlaylistItem(fromIndex: Int, toIndex: Int) {
        guard playlist.indices.contains(fromIndex),
              playlist.indices.contains(toIndex),
              fromIndex != toIndex
        else { return }
        let item = playlist.remove(at: fromIndex)
        playlist.insert(item, at: toIndex)
        // keep now-playing tracked across the move
        if currentIndex == fromIndex {
            currentIndex = toIndex
        } else if fromIndex < currentIndex && toIndex >= currentIndex {
            currentIndex -= 1
        } else if fromIndex > currentIndex && toIndex <= currentIndex {
            currentIndex += 1
        }
    }

    // MARK: - Grip drag reorder

    private var dragSourceIndex: Int?
    private var lastDragY: CGFloat = 0
    private static let rowHeight: CGFloat = 26.0

    func dragReorder(draggedIndex: Int, translationY: CGFloat) {
        if dragSourceIndex == nil {
            dragSourceIndex = draggedIndex
            lastDragY = 0
        }
        guard dragSourceIndex == draggedIndex else { return }

        // swap rows as the drag crosses a full row height
        let delta = Int((translationY - lastDragY) / Self.rowHeight)
        guard delta != 0 else { return }
        let current = dragSourceIndex!
        var moved = false
        for _ in 0..<abs(delta) {
            let target = delta > 0 ? current + 1 : current - 1
            guard playlist.indices.contains(target) else { break }
            movePlaylistItem(fromIndex: current, toIndex: target)
            dragSourceIndex = target
            moved = true
            // step the reference point so translation stays relative
            lastDragY += CGFloat(delta > 0 ? Self.rowHeight : -Self.rowHeight)
            break // one row per gesture tick; onChanged keeps firing
        }
    }

    func finishDragReorder() {
        dragSourceIndex = nil
        lastDragY = 0
    }

    func clearPlaylist() {
        player.drawable = nil
        player.delegate = nil
        player.stop()
        let fresh = VLCMediaPlayer(options: ["--no-video-title-show"])
        fresh.delegate = self
        player = fresh
        playlist.removeAll()
        currentIndex = -1
        currentURL = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
}

extension PlayerViewModel: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        Task { @MainActor in
            isPlaying = newState == .playing
            // VLCKit 4 has no .ended state; a natural end-of-media surfaces as .stopped
            if newState == .stopped, currentIndex >= 0, currentURL != nil {
                playNext()
            }
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            currentTime = Double(player.time.intValue) / 1000.0
        }
    }

    nonisolated func mediaPlayerLengthChanged(_ length: Int64) {
        Task { @MainActor in
            if length > 0 {
                duration = Double(length) / 1000.0
            }
        }
    }
}
