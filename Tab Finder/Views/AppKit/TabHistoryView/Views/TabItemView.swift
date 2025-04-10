import Cocoa

final class TabItemView: NSView {
    private var eventMonitor: Any?
    
    init() {
        super.init(frame: .zero)
        
        let hostLabel = NSTextField(labelWithString: "Test")
        hostLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(hostLabel)
        
        NSLayoutConstraint.activate([
            hostLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hostLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hostLabel.topAnchor.constraint(equalTo: self.topAnchor),
            hostLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
        
        setupTrackingArea()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }
    
    override func mouseEntered(with event: NSEvent) {
        self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] scrollWheelEvent in
            print(event	)
            return event
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
    }
    
    override func mouseExited(with event: NSEvent) {
    }
}
