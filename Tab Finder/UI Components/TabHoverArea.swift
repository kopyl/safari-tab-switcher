/// source: https://stackoverflow.com/questions/71778864/hover-effect-for-swiftui-shapes-for-the-mac

import SwiftUI

class TrackingNSHostingView<Content>: NSHostingView<Content> where Content : View {
    let action: (Bool) -> Void
    
    init(action: @escaping (Bool) -> Void, rootView: Content) {
        self.action = action
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
        self.action(false)
    }
    
    override func mouseMoved(with event: NSEvent) {
        return self.checkInside(with: event)
    }
    
    private func checkInside(with event: NSEvent) {
        let inside = self.frame.contains(self.convert(event.locationInWindow, from: nil))
        self.action(inside)
    }
}

struct TrackingAreaRepresentable<Content>: NSViewRepresentable where Content: View {
    let action: (Bool) -> Void
    let content: Content
    
    func makeNSView(context: Context) -> NSHostingView<Content> {
        return TrackingNSHostingView(action: action, rootView: self.content)
    }
    
    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
    }
}

struct HoverInsideModifier: ViewModifier {
    let action: (Bool) -> Void
    
    func body(content: Content) -> some View {
        TrackingAreaRepresentable(action: action, content: content)
    }
}

extension View {
    func onMouseMove(action: @escaping (Bool) -> Void) -> some View {
        self.modifier(HoverInsideModifier(action: action))
    }
}
