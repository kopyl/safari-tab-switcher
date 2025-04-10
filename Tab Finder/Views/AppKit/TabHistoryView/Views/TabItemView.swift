import Cocoa

class SwipeActionConfig {
    static let fullSwipeThreshold: CGFloat = 300
    static let fullSwipeAnimationDuration: CGFloat = 0.05
    static let spacing: CGFloat = 0
    static let cornerRadius: CGFloat = 0
}

final class TabItemView: NSView {
    let tab: Tab
    var onTabHover: ((Int) -> Void)?
    var onTabClose: ((Int) -> Void)? {
        didSet {
            self.closeButon.onTabClose = onTabClose
        }
    }
    
    public var firstColumnLabel: NSTextField
    public var seconColumnLabel: NSTextField
    public var closeButon: CloseButton
    
    let contentView = NSView()
    
    private var swipeActionViewLeadingConstraint = NSLayoutConstraint()
    private var swipeActionViewTrailingConstraint = NSLayoutConstraint()
    private var scrollEventMonitor: Any?
    
    init(tab: Tab) {
        self.tab = tab
        
        switch appState.columnOrder {
        case .host_title:
            self.firstColumnLabel = NSTextField(labelWithString: tab.host)
            self.seconColumnLabel = NSTextField(labelWithString: tab.title)
        case .title_host:
            self.firstColumnLabel = NSTextField(labelWithString: tab.title)
            self.seconColumnLabel = NSTextField(labelWithString: tab.host)
        }
        
        self.closeButon = CloseButton(tab: tab)
        self.closeButon.isHidden = true
        
        super.init(frame: .zero)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.wantsLayer = true
        
        self.clipsToBounds = true
        self.wantsLayer = true
        self.layer?.cornerRadius = 4
        
        let swipeActionView = makeSwipeActionView()
        
        self.addSubview(swipeActionView)
        self.addSubview(contentView)
        
        swipeActionViewLeadingConstraint = swipeActionView.leadingAnchor.constraint(equalTo: self.trailingAnchor)
        swipeActionViewTrailingConstraint = swipeActionView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        
        // Configure labels
        if tab.host == "" {
            firstColumnLabel.stringValue = "No title"
        }
        firstColumnLabel.lineBreakMode = .byTruncatingTail
        firstColumnLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        firstColumnLabel.font = .systemFont(ofSize: 18)
        firstColumnLabel.textColor = .tabFg

        seconColumnLabel.lineBreakMode = .byTruncatingTail
        seconColumnLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        seconColumnLabel.font = .systemFont(ofSize: 13)
        seconColumnLabel.textColor = .tabFg

        let stackView = NSStackView()
        
        stackView.orientation = .horizontal
        
        // Set distribution based on column order
        if appState.columnOrder == .title_host {
            stackView.distribution = .fill
            stackView.spacing = 20
        } else {
            stackView.distribution = .fillEqually
            stackView.spacing = 8
        }
        
        stackView.edgeInsets = .init(top: 0, left: 57, bottom: 0, right: 50)
        stackView.addArrangedSubview(firstColumnLabel)
        stackView.addArrangedSubview(seconColumnLabel)
        
        let faviconView = FaviconView(tab: tab)

        // Add all elements to contentView
        contentView.addSubview(stackView)
        contentView.addSubview(faviconView)
        contentView.addSubview(closeButon)
        
        // Make contentView fill the parent view
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: self.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup constraints for stackView and other elements inside contentView
        NSLayoutConstraint.activate([
            swipeActionViewLeadingConstraint,
            swipeActionViewTrailingConstraint,
            swipeActionView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            swipeActionView.heightAnchor.constraint(equalTo: self.heightAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            faviconView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 21),
            faviconView.widthAnchor.constraint(equalToConstant: faviconView.width),
            faviconView.heightAnchor.constraint(equalToConstant: faviconView.height),
            faviconView.centerYAnchor.constraint(equalTo: stackView.centerYAnchor),
            
            closeButon.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            closeButon.widthAnchor.constraint(equalToConstant: tabHeight),
            closeButon.heightAnchor.constraint(equalToConstant: tabHeight),
        ])
        
        // Add specific width constraint for second column if in title_host mode
        if appState.columnOrder == .title_host {
            let secondColumnWidthConstraint = seconColumnLabel.widthAnchor.constraint(equalToConstant: 200)
            secondColumnWidthConstraint.isActive = true
            
            // Make sure the first column can grow but has a minimum width
            firstColumnLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            seconColumnLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        } else {
            // For the equal distribution case, ensure both have same hugging priority
            firstColumnLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            seconColumnLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        
        setupTrackingArea()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        appState.indexOfTabToSwitchTo = tab.renderIndex
        hideTabsPanelAndSwitchTabs()
    }
    
    func setupTrackingArea() {
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil))
    }
    
    override func mouseMoved(with event: NSEvent) {
        onTabHover?(tab.renderIndex)
        closeButon.isHidden = false
    }
    
    private var isRunningFullSwipe: Bool = false
    private var isRunningFullSwipeFinished: Bool = false
    
    private func removeEventMonitor() {
        if let monitor = scrollEventMonitor {
            NSEvent.removeMonitor(monitor)
            scrollEventMonitor = nil
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        
        print(event)
        super.scrollWheel(with: event)
        
        let changeToLeadingConstraintSwipe: CGFloat = self.swipeActionViewLeadingConstraint.constant + event.scrollingDeltaX
        
        self.swipeActionViewLeadingConstraint.constant = changeToLeadingConstraintSwipe
        self.contentView.layer?.position.x = changeToLeadingConstraintSwipe
        
        self.layoutSubtreeIfNeeded()
    }
    
    
    override func mouseExited(with event: NSEvent) {
        closeButon.isHidden = true
    }
    
    override func viewDidHide() {
        print("removing event")
        removeEventMonitor()
    }
}
