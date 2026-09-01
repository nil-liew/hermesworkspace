import SwiftUI
import VLCKit

struct VideoContainerView: NSViewRepresentable {
    let vm: PlayerViewModel
    let onFiles: ([URL]) -> Void

    final class Coordinator {
        var appliedSteps = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = DropView()
        view.onFiles = onFiles
        view.onMousePosition = { [weak vm] point in
            vm?.currentMouseFraction = point
        }
        vm.player.drawable = view
        vm.videoView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DropView)?.onFiles = onFiles
        if vm.player.drawable == nil {
            vm.player.drawable = nsView
            context.coordinator.appliedSteps = -2
        }
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

    /// Apply zoom transform to the NSView layer, centered at the given anchor point.
    private func applyZoom(to view: NSView, scale: Double, anchor: CGPoint) {
        guard let layer = view.layer else { return }

        if scale <= 1.0 {
            layer.transform = CATransform3DIdentity
            layer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
            layer.position = CGPoint(x: 0, y: 0)
            view.frame = view.bounds
            return
        }

        layer.anchorPoint = anchor
        let transform = CATransform3DMakeScale(CGFloat(scale), CGFloat(scale), 1.0)
        layer.transform = transform
    }
}

final class DropView: NSView {
    var onFiles: (([URL]) -> Void)?
    var onMouseMove: ((Double, Double) -> Void)?
    var onMousePosition: ((CGPoint) -> Void)?

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
              !urls.isEmpty
        else { return false }
        DispatchQueue.main.async { self.onFiles?(urls) }
        return true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let fractionX = bounds.width > 0 ? point.x / bounds.width : 0.5
        let fractionY = bounds.height > 0 ? 1.0 - (point.y / bounds.height) : 0.5 // Flip Y
        let mousePos = CGPoint(x: fractionX, y: fractionY)
        onMousePosition?(mousePos)
        onMouseMove?(fractionX, fractionY)
    }
}

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var showPlaylist = false
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    @State private var dragSelection: Int?
    @State private var showCheatsheet = false

    init() {
        _vm = StateObject(wrappedValue: PlayerViewModel())
    }

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
                Button("") { vm.captureScreenshot() }
                    .keyboardShortcut("-", modifiers: [])
                Button("") { vm.toggleClip() }
                    .keyboardShortcut("+", modifiers: [])
                Button(action: { withAnimation { showCheatsheet.toggle() } }) {
                    EmptyView()
                }
                .keyboardShortcut("i", modifiers: [])
                Button("") { openFiles() }
                    .keyboardShortcut("o", modifiers: [])
                Button(action: { withAnimation { showPlaylist.toggle() } }) {
                    EmptyView()
                }
                .keyboardShortcut("p", modifiers: [])
                Button("") { vm.toggleZoom() }
                    .keyboardShortcut("z", modifiers: [])
            }
            .opacity(0)
        )
    }

    private var videoArea: some View {
        ZStack {
            Color.black
            if vm.currentURL == nil {
                Text("Drag a video here to start")
                    .foregroundColor(Color(white: 0.3))
            }
            VideoContainerView(vm: vm) { urls in
                vm.addToPlaylistAndPlay(urls)
            }
            .scaleEffect(vm.zoomScale, anchor: UnitPoint(x: vm.zoomAnchor.x, y: vm.zoomAnchor.y))

            VStack {
                Spacer()
                HStack {
                    if vm.isSpeeding, let label = vm.speedLabel {
                        Text(label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    if vm.isClipping {
                        Label("CLIPPING", systemImage: "record.circle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    if let msg = vm.clippingMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = vm.clippingMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showCheatsheet {
                CheatsheetView()
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Shortcut cheatsheet overlay

    private struct CheatsheetRow: Identifiable {
        let id = UUID()
        let keys: String
        let action: String
    }

    private static let cheatRows: [CheatsheetRow] = [
        .init(keys: "Space", action: "Play / Pause"),
        .init(keys: "1 / 2", action: "−1 / +1 frame"),
        .init(keys: "4 / 5", action: "−15 / +15 seconds"),
        .init(keys: "7 / 8", action: "−60 / +60 seconds"),
        .init(keys: "← hold / → hold", action: "2× Rewind / Fast-forward"),
        .init(keys: "[ / ]", action: "Rotate counter-clockwise / clockwise"),
        .init(keys: "↑ / ↓", action: "Previous / next file"),
        .init(keys: "0", action: "Normal ↔ full display size"),
        .init(keys: "o", action: "Open files"),
        .init(keys: "p", action: "Toggle playlist panel"),
        .init(keys: "-", action: "Screenshot → <name> <N>.jpg"),
        .init(keys: "+", action: "Start / stop video clipping"),
        .init(keys: "i", action: "Toggle this cheatsheet"),
        .init(keys: "z", action: "Zoom 3× at cursor"),
    ]

    private struct CheatsheetView: View {
        let rows = ContentView.cheatRows

        private func rowView(_ row: CheatsheetRow) -> some View {
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
                Text("press i or click ⓘ to close")
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

            Button(action: { withAnimation { showCheatsheet.toggle() } }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Keyboard shortcuts (i)")
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
