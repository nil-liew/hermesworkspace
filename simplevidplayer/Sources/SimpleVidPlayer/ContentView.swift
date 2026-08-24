import SwiftUI
import VLCKit

struct VideoContainerView: NSViewRepresentable {
    let vm: PlayerViewModel
    let onFile: (URL) -> Void

    final class Coordinator {
        var appliedSteps = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = DropView()
        view.onFile = onFile
        vm.player.drawable = view
        vm.videoView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DropView)?.onFile = onFile
        if vm.player.drawable == nil {
            vm.player.drawable = nsView
            // fresh drawable: force rotation to be re-applied once the vout settles
            context.coordinator.appliedSteps = -2
        }
        // CRITICAL: only touch geometry when the rotation step CHANGED.
        // Re-applying frames/transforms while a vout is initializing aborts VLCKit.
        if context.coordinator.appliedSteps != vm.rotationSteps {
            applyRotation(to: nsView, steps: vm.rotationSteps)
            context.coordinator.appliedSteps = vm.rotationSteps
        }
    }

    /// Rotate the drawable view in 90° steps. For 90°/270° swap the frame's
    /// width/height so the rotated picture fits the container.
    private func applyRotation(to view: NSView, steps: Int) {
        guard let superview = view.superview else { return }
        let bounds = superview.bounds
        let w = bounds.width, h = bounds.height

        if steps % 4 == 0 {
            view.layer?.transform = CATransform3DIdentity
            view.frame = bounds
            view.setFrameOrigin(.zero)
            return
        }

        let swapped = (steps == 1 || steps == 3)
        var frameW = swapped ? h : w
        var frameH = swapped ? w : h
        if swapped {
            // A w×h view rotated 90° occupies h×w on screen. Scale it down so
            // the rotated result fits inside the w×h container.
            let s = min(h / max(w, 1), w / max(h, 1))
            frameW = w * s
            frameH = h * s
        }
        view.frame = CGRect(x: 0, y: 0, width: frameW, height: frameH)
        view.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        view.layer?.position = CGPoint(x: w / 2, y: h / 2)
        let angle: CGFloat = steps == 1 ? -90 : (steps == 2 ? 180 : 90) // CA rotation is CCW-positive
        view.layer?.transform = CATransform3DMakeRotation(angle * .pi / 180, 0, 0, 1)
    }
}

final class DropView: NSView {
    var onFile: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                               options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let url = urls.first
        else { return false }
        DispatchQueue.main.async { self.onFile?(url) }
        return true
    }
}

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var showPlaylist = false
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var dragSelection: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                videoArea
                if showPlaylist {
                    playlistPanel
                }
            }
            controlsBar
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .background(
            VStack {
                Button("") { vm.togglePlay() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("") { vm.rotateClockwise() }
                    .keyboardShortcut("]", modifiers: [])
                Button("") { vm.rotateCounterClockwise() }
                    .keyboardShortcut("[", modifiers: [])
                Button("") { vm.playPrevious() }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("") { vm.playNext() }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("") { vm.cycleScreenSize() }
                    .keyboardShortcut("0", modifiers: [])
                Button("") { vm.stepFrames(-1) }
                    .keyboardShortcut("1", modifiers: [])
                Button("") { vm.stepFrames(1) }
                    .keyboardShortcut("2", modifiers: [])
                Button("") { vm.seekBy(-15) }
                    .keyboardShortcut("4", modifiers: [])
                Button("") { vm.seekBy(15) }
                    .keyboardShortcut("5", modifiers: [])
                Button("") { vm.seekBy(-60) }
                    .keyboardShortcut("7", modifiers: [])
                Button("") { vm.seekBy(60) }
                    .keyboardShortcut("8", modifiers: [])
                Button("") { openFiles() }
                    .keyboardShortcut("o", modifiers: [])
                Button(action: { withAnimation { showPlaylist.toggle() } }) {
                    EmptyView()
                }
                .keyboardShortcut("p", modifiers: [])
            }
            .opacity(0)
        )
    }

    // MARK: - Video area

    private var videoArea: some View {
        ZStack {
            Color.black
            if vm.currentURL == nil {
                Text("Open a video to start")
                    .foregroundColor(Color(white: 0.3))
            }
            VideoContainerView(vm: vm) { url in
                vm.addToPlaylistAndPlay([url])
            }
        }
    }

    // MARK: - Controls bar

    private var controlsBar: some View {
        HStack(spacing: 14) {
            Button(action: { vm.togglePlay() }) {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .frame(width: 28)
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)

            Text(timeString(vm.currentTime))
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(.secondary)

            ScrubBar(
                fraction: Binding(
                    get: {
                        if isSeeking { return seekValue }
                        return vm.duration > 0 ? vm.currentTime / vm.duration : 0
                    },
                    set: { newValue in
                        seekValue = newValue
                        isSeeking = true
                        if vm.duration > 0 {
                            vm.player.time = VLCTime(int: Int32(newValue * vm.duration * 1000))
                            vm.currentTime = newValue * vm.duration
                        }
                    }
                ),
                onEnd: { isSeeking = false }
            )

            Text(timeString(vm.duration))
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(.secondary)

            Spacer()

            Button("Open") { openFiles() }
                .buttonStyle(.borderless)

            Button(action: { withAnimation { showPlaylist.toggle() } }) {
                Image(systemName: "list.bullet")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor(red: 0.086, green: 0.086, blue: 0.106, alpha: 1)))
    }

    // MARK: - Playlist panel

    private var playlistPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Playlist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { addFiles() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add files")

                Button(action: { vm.clearPlaylist() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear playlist")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(vm.playlist.enumerated()), id: \.element.id) { index, item in
                        PlaylistRowView(
                            index: index,
                            item: item,
                            isCurrent: vm.currentIndex == index,
                            isPlaying: vm.isPlaying
                        ) {
                            vm.play(at: index)
                        } onRemove: {
                            vm.removeFromPlaylist(at: IndexSet(integer: index))
                        } onDrag: { translation in
                            vm.dragReorder(draggedIndex: index, translationY: translation)
                        } onDragEnd: {
                            vm.finishDragReorder()
                        }
                        .background(
                            // drop highlight slot
                            Rectangle().fill(Color.clear)
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity)

            if vm.playlist.isEmpty {
                Spacer()
                Text("Playlist empty\nDrop video files or click +")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .frame(width: 260)
        .background(Color(NSColor(red: 0.078, green: 0.078, blue: 0.102, alpha: 1)))
    }

    // MARK: - Actions

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose videos"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video]
        if panel.runModal() == .OK {
            let urls = panel.urls
            if vm.currentURL == nil, let first = urls.first {
                vm.addToPlaylistAndPlay(urls)
            } else {
                vm.addToPlaylistAndPlay(urls)
            }
        }
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.title = "Add videos to playlist"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video]
        if panel.runModal() == .OK {
            vm.addToPlaylist(panel.urls)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "00:00" }
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Custom scrub bar (full drag support)

// Playlist row: tap = play, x = remove, grip = drag to reorder.
struct PlaylistRowView: View {
    let index: Int
    let item: PlaylistItem
    let isCurrent: Bool
    let isPlaying: Bool
    var onPlay: () -> Void
    var onRemove: () -> Void
    var onDrag: (CGFloat) -> Void
    var onDragEnd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPlay) {
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 18, alignment: .trailing)
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundColor(isCurrent ? Color(red: 1.0, green: 0.85, blue: 0.66) : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isCurrent {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "pause")
                    .font(.system(size: 9))
                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.66))
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(0.6)

            // Drag grip — drag up/down to reorder
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .opacity(0.5)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { g in onDrag(g.translation.height) }
                        .onEnded { _ in onDragEnd() }
                )
                .onHover { hovering in
                    if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }
        }
        .padding(.vertical, 4)
        .background(isCurrent ? Color.white.opacity(0.04) : Color.clear)
    }
}

struct ScrubBar: View {
    @Binding var fraction: Double
    var onEnd: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 4)
                Capsule()
                    .fill(Color(red: 0.66, green: 0.78, blue: 0.98))
                    .frame(width: max(0, min(w, CGFloat(fraction) * w)), height: 4)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        fraction = Double(max(0, min(1, g.location.x / w)))
                    }
                    .onEnded { _ in
                        onEnd()
                    }
            )
        }
        .frame(height: 18)
    }
}
