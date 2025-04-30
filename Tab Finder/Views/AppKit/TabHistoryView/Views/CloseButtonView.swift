import Cocoa

final class CloseButtonView: NSView {
    let button = makeCloseButton()
    let tab: Tab
    let hoverBackgroundView: NSView
    
    var onTabClose: ((Int) -> Void)?
    
    init(tab: Tab) {
        self.tab = tab
        
        self.hoverBackgroundView = makeColorView()
        
        self.hoverBackgroundView.layer?.cornerRadius = 4
        
        super.init(frame: .zero)
        
        button.target = self
        button.action = #selector(closeButtonPressed)
        
        setupTrackingArea()
        
        self.addSubview(button)
        self.addSubview(hoverBackgroundView    )
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: tabHeight),
            button.heightAnchor.constraint(equalToConstant: tabHeight),
            
            hoverBackgroundView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            hoverBackgroundView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            hoverBackgroundView.widthAnchor.constraint(equalToConstant: 20),
            hoverBackgroundView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    override func viewDidChangeEffectiveAppearance() {
        self.hoverBackgroundView.layer?.backgroundColor = NSColor.lightGrey.cgColorAppearanceFix
    }
    
    override func mouseMoved(with event: NSEvent) {
        self.hoverBackgroundView.layer?.opacity = 1
    }
    
    override func mouseExited(with event: NSEvent) {
        self.hoverBackgroundView.layer?.opacity = 0
    }
    
    func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }
    
    @objc func closeButtonPressed() {
        onTabClose?(self.tab.id)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

