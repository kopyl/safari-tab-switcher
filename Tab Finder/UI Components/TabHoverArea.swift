/// source: https://stackoverflow.com/questions/71778864/hover-effect-for-swiftui-shapes-for-the-mac

import SwiftUI

class TrackingNSHostingView<Content>: NSHostingView<Content> where Content : View {
    let insideShape: (Bool) -> Void
    
    init(insideShape: @escaping (Bool) -> Void, rootView: Content) {
        self.insideShape = insideShape
        super.init(rootView: rootView)
        setupTrackingArea()
    }
    
    required init(rootView: Content) {
        fatalError("init(rootView:) has not been implemented")
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }
        
    override func mouseExited(with event: NSEvent) {
        self.insideShape(false)
    }
    
    override func mouseMoved(with event: NSEvent) {
        return self.checkInside(with: event)
    }
    
    private func checkInside(with event: NSEvent) {
        let inside = self.frame.contains(self.convert(event.locationInWindow, from: nil))
        self.insideShape(inside)
    }
}

struct TrackingAreaRepresentable<Content>: NSViewRepresentable where Content: View {
    let insideShape: (Bool) -> Void
    let content: Content
    
    func makeNSView(context: Context) -> NSHostingView<Content> {
        return TrackingNSHostingView(insideShape: insideShape, rootView: self.content)
    }
    
    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
    }
}


struct TrackingAreaView<Content>: View where Content : View {
    let insideShape: (Bool) -> Void
    let content: () -> Content
    
    init(insideShape: @escaping (Bool) -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.insideShape = insideShape
        self.content = content
    }
    
    var body: some View {
        TrackingAreaRepresentable(insideShape: insideShape, content: self.content())
    }
}

extension View {
    func onHoverInside(action: @escaping (Bool) -> Void) -> some View {
        TrackingAreaView(insideShape: action) { self }
    }
}
