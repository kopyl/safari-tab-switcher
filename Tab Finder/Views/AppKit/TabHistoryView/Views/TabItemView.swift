import Cocoa

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
        
        let stackView: NSStackView = .init()

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

        self.addSubview(faviconView)
        self.addSubview(stackView)

        self.addSubview(closeButon)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Basic constraints for all layouts
        let constraints = [
            faviconView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 21),
            faviconView.widthAnchor.constraint(equalToConstant: faviconView.width),
            faviconView.heightAnchor.constraint(equalToConstant: faviconView.height),
            faviconView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: self.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            closeButon.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            closeButon.widthAnchor.constraint(equalToConstant: tabHeight),
            closeButon.heightAnchor.constraint(equalToConstant: tabHeight),
        ]
        
        NSLayoutConstraint.activate(constraints)
        
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
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }
    
    override func mouseMoved(with event: NSEvent) {
        onTabHover?(tab.renderIndex)
        closeButon.isHidden = false
    }
    
    override func mouseExited(with event: NSEvent) {
        closeButon.isHidden = true
    }
}
