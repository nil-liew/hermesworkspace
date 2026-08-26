import SwiftUI
import AppKit

/// AppKit-level drop target that reliably accepts file drops every time.
/// (SwiftUI's dropDestination stops responding after the first drop when
/// the view hierarchy rebuilds.)
struct FileDropZone<Content: View>: View {
    let onDrop: ([URL]) -> Void
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        DropZoneRepresentable(onDrop: onDrop, content: content())
    }
}

private struct DropZoneRepresentable<Content: View>: NSViewRepresentable {
    let onDrop: ([URL]) -> Void
    let content: Content
    
    func makeNSView(context: Context) -> DropHostingView<Content> {
        print("[SIV] DropZone: makeNSView")
        let view = DropHostingView(rootView: content)
        view.onFilesDropped = { urls in
            print("[SIV] DropZone: received \(urls.count) files")
            DispatchQueue.main.async {
                onDrop(urls)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: DropHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

/// NSHostingView subclass handling drag-and-drop at the AppKit layer
final class DropHostingView<Content: View>: NSHostingView<Content> {
    var onFilesDropped: (([URL]) -> Void)?
    
    required override init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
        print("[SIV] DropZone: initialized, registered for fileURL")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Re-register in case the view was moved between hierarchies
        if window != nil {
            registerForDraggedTypes([.fileURL])
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("[SIV] DropZone: draggingEntered")
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("[SIV] DropZone: performDragOperation")
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                                options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else {
            print("[SIV] DropZone: no file URLs on pasteboard")
            return false
        }
        print("[SIV] DropZone: dropping \(urls.count) URLs")
        onFilesDropped?(urls)
        return true
    }
}
