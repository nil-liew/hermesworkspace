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
    // Video rotation in 90° steps: 0 = none, 1 = 90° CW, 2 = 180°, 3 = 270° (90° CCW)
    @Published var rotationSteps = 0
    // Screen size cycle: 0 = normal (1x), 1 = half (0.5x), 2 = double (2x)
    @Published var screenSizeStep = 0
    // Video fps from parsed media metadata; 0 = unknown (frame step falls back to 30fps)
    var framesPerSecond: Double = 0

    override init() {
        super.init()
        player.delegate = self
        installKeyMonitor()
    }

    // Hold ← / → for 2× rewind / fast-forward. Raw NSEvent monitor lives here
    // so there is no wiring race with the app delegate.
    private var keyMonitor: Any?

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            switch (event.type, event.keyCode) {
            case (.keyDown, 123): self.startRewind(); return nil
            case (.keyDown, 124): self.startFastForward(); return nil
            case (.keyUp, 123), (.keyUp, 124): self.restoreRate(); return nil
            default: return event
            }
        }
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
        rotationSteps = 0
        pendingURL = url
        scheduleSwap()
    }

    /// Serializes player swaps. Rapid file jumps (↑/↓, row clicks, auto-advance)
    /// collapse into one swap for the LAST requested URL — the GL vout asserts if
    /// a new player attaches to the view while the previous swap is still settling.
    private func scheduleSwap() {
        guard !swapPending else { return }
        swapPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.swapPending = false
            guard let url = self.pendingURL else { return }
            self.performSwap(to: url)
        }
    }

    private var swapPending = false
    private var pendingURL: URL?

    private func performSwap(to url: URL) {
        // If more requests arrived while we were settling, run the latest again.
        if pendingURL != url {
            scheduleSwap()
            return
        }
        pendingURL = nil

        // Stop the retiring player FIRST, on a background queue, and wait for it.
        // The AVI crash showed the old player's OpenGL vout still drawing on the
        // main thread while a fresh player attached to the same view. Waiting for
        // stop() makes the handover exclusive. stop() itself runs off-main, so
        // this short main-thread wait cannot deadlock.
        let retiring = player
        retiring.delegate = nil
        retiring.drawable = nil
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            retiring.stop()
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 2.0)

        guard let media = VLCMedia(url: url) else { return }
        framesPerSecond = 0   // unknown until tracks are parsed

        // async parse to learn fps for accurate frame stepping
        let parser = VLCMediaParser(library: VLCLibrary.shared(), timeout: 5000)
        _ = parser.queue(media, options: [.init(rawValue: 0x01)])   // VLCMediaParse

        let fresh = VLCMediaPlayer(options: ["--no-video-title-show"])
        fresh.delegate = self
        fresh.media = media
        player = fresh
        if let view = videoView {
            fresh.drawable = view
        }
        fresh.play()

        // Poll briefly for parsed fps (frame stepping accuracy). Falls back to 30fps.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for _ in 0..<20 {
                Thread.sleep(forTimeInterval: 0.25)
                guard let self, self.currentURL == url else { return }
                if self.readFPS(from: media) > 0 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.currentURL == url else { return }
                        self.framesPerSecond = self.readFPS(from: media)
                    }
                    return
                }
            }
        }
    }

    private func readFPS(from media: VLCMedia) -> Double {
        guard let track = media.tracksInformation.first(where: { $0.video != nil }),
              let video = track.video,
              video.frameRate > 0
        else { return 0 }
        let den = max(1.0, Double(video.frameRateDenominator))
        return Double(video.frameRate) / den
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

    // MARK: - Rotation

    func rotateClockwise() {
        rotationSteps = (rotationSteps + 1) % 4
    }

    func rotateCounterClockwise() {
        rotationSteps = (rotationSteps + 3) % 4
    }

    // MARK: - Seeking (frame step & time skips)

    /// Frame step using VLCKit's native frame stepper (exact, fps-aware).
    /// Auto-pauses playback on first step, matching standard player behavior.
    func stepFrames(_ count: Int) {
        if count >= 1 {
            for _ in 0..<count { player.gotoNextFrame() }
        } else if count <= -1 {
            for _ in 0..<(-count) { player.gotoPreviousFrame() }
        }
    }

    func seekBy(_ seconds: TimeInterval) {
        let current = Double(player.time.intValue) / 1000.0
        let newTime = max(0, min(duration > 0 ? duration : .infinity, current + seconds))
        player.time = VLCTime(int: Int32(newTime * 1000))
        currentTime = newTime
    }

    // MARK: - Playback rate (hold ← 2× rewind, hold → 2× forward)

    @Published var isSpeeding = false
    @Published var speedLabel: String?

    func startFastForward() {
        guard !isSpeeding else { return }
        isSpeeding = true
        speedLabel = "2x ▶▶"
        player.fastForward(atRate: 2.0)
    }

    func startRewind() {
        guard !isSpeeding else { return }
        isSpeeding = true
        speedLabel = "◀◀ 2x"
        // VLC rewind(atRate:) only works on streams supporting backward playback
        // (most files don't). Simulate 2× rewind by jumping back 2×-realtime.
        // NOTE: keep the player PLAYING — pausing here puts the decoder into
        // frame-step mode and rapid seeks while paused abort VLCKit internally
        // (Decoder_PausedForNextFrame assert). Playing-state seeks are safe.
        seekBy(-1.0)   // immediate first jump so the hold feels instant
        rewindTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSpeeding else { return }
                self.seekBy(-1.0)   // 0.25s tick × ~4 jumps/s ≈ 2× realtime
            }
        }
    }

    private var rewindTimer: Timer?

    func restoreRate() {
        guard isSpeeding else { return }
        isSpeeding = false
        speedLabel = nil
        rewindTimer?.invalidate()
        rewindTimer = nil
        player.rate = 1.0
    }

    // MARK: - Screenshot ("-")

    /// Captures the current video frame and saves it as
    /// "<sourceName> <N>.jpg" in the source file's folder.
    func captureScreenshot() {
        guard let sourceURL = currentURL else { return }
        let folder = sourceURL.deletingLastPathComponent()
        let base = sourceURL.deletingPathExtension().lastPathComponent

        // Find next free incremental suffix
        var index = 1
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(base) \(index).jpg").path) {
            index += 1
        }
        let destURL = folder.appendingPathComponent("\(base) \(index).jpg")

        // VLCKit snapshots to its own naming inside the given path; snapshot into
        // a temp dir, then convert to JPEG with our name.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("svp-shot-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        player.saveVideoSnapshot(at: tmpDir.path, withWidth: 0, andHeight: 0)

        // Give VLC a beat to finish writing, then grab the newest file
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) {
            let files = ((try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
                .filter { $0.pathExtension.lowercased() == "png" || $0.pathExtension.lowercased() == "jpg" }
                .sorted(by: { lhs, rhs in
                    let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return l > r
                })
            guard let snap = files.first,
                  let ciImage = CIImage(contentsOf: snap),
                  let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
            else {
                try? FileManager.default.removeItem(at: tmpDir)
                return
            }
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) {
                try? jpegData.write(to: destURL)
            }
            try? FileManager.default.removeItem(at: tmpDir)
            DispatchQueue.main.async { [weak self] in
                self?.lastScreenshotPath = destURL
            }
        }
    }

    /// Path of the most recent screenshot (for UI feedback).
    @Published var lastScreenshotPath: URL?

    // MARK: - Video clipping ("+" start, "+" again stop)

    @Published var isClipping = false
    @Published var clippingMessage: String?
    private var clipStart: TimeInterval = 0
    private var clipProcess: Process?

    /// "+" starts a clip at the current playhead; pressing "+" again stops and
    /// saves "<sourceName> clip <N>.<ext>" (source container format) in the
    /// source folder via ffmpeg stream-copy (no re-encode).
    func toggleClip() {
        if isClipping {
            stopClipAndSave()
        } else {
            guard let sourceURL = currentURL else { return }
            clipStart = Double(player.time.intValue) / 1000.0
            isClipping = true
            clippingMessage = "Clipping from \(timeString(clipStart)) — press + to stop"
        }
    }

    private func stopClipAndSave() {
        guard isClipping,
              let sourceURL = currentURL,
              let ffmpeg = locateFFmpeg()
        else {
            isClipping = false
            return
        }
        isClipping = false
        let start = clipStart
        let duration = max(0.1, Double(player.time.intValue) / 1000.0 - start)
        let folder = sourceURL.deletingLastPathComponent()
        let base = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension

        var index = 1
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(base) clip \(index).\(ext)").path) {
            index += 1
        }
        let destURL = folder.appendingPathComponent("\(base) clip \(index).\(ext)")

        clippingMessage = "Saving clip…"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process()
            p.executableURL = ffmpeg
            p.arguments = ["-y",
                           "-ss", String(format: "%.3f", start),
                           "-i", sourceURL.path,
                           "-t", String(format: "%.3f", duration),
                           "-c", "copy",
                           "-avoid_negative_ts", "make_zero",
                           destURL.path]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if p.terminationStatus == 0 {
                    self.clippingMessage = "Saved \(destURL.lastPathComponent)"
                } else {
                    self.clippingMessage = "Clip failed (ffmpeg exit \(p.terminationStatus))"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    self?.clippingMessage = nil
                }
            }
        }
    }

    /// Finds ffmpeg in common locations (PATH may be absent for GUI apps).
    private func locateFFmpeg() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            return URL(fileURLWithPath: c)
        }
        return nil
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Screen size toggle ("0"): normal <-> fit full display

    func cycleScreenSize() {
        screenSizeStep = (screenSizeStep + 1) % 2
        resizeWindow(for: screenSizeStep)
    }

    private func resizeWindow(for step: Int) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }
        let vis = screen.visibleFrame
        let newSize: CGSize
        if step == 1 {
            newSize = vis.size   // fit full display
        } else {
            newSize = CGSize(width: 960, height: 592)   // default size
        }
        // Center in the visible screen frame
        let newFrame = NSRect(
            x: vis.midX - newSize.width / 2,
            y: vis.midY - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        window.setFrame(newFrame, display: true, animate: true)
    }

    func playNext() {
        let next = currentIndex + 1
        if next < playlist.count {
            play(at: next)
        }
    }

    func playPrevious() {
        let prev = currentIndex - 1
        if prev >= 0 {
            play(at: prev)
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
                let retiring = player
                retiring.delegate = nil
                retiring.drawable = nil
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                    retiring.stop()
                }
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
        let retiring = player
        retiring.delegate = nil
        retiring.drawable = nil
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
            retiring.stop()
        }
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
