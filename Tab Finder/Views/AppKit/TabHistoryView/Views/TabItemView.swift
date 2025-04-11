import Cocoa

class SwipeActionConfig {
    static let partialRightSwipeThreshold: CGFloat = 200
    
    static let fullSwipeThreshold: CGFloat = 300
    static let fullSwipeAnimationDuration: CGFloat = 0.05
    static let spacing: CGFloat = 4
    static let cornerRadius: CGFloat = 6
}

final class TabItemView: NSView {
    let tab: Tab
    var onTabHover: ((Int) -> Void)?
    var onTabClose: ((Int) -> Void)? {
        didSet {
            self.closeButonView.onTabClose = onTabClose
        }
    }
    
    public var firstColumnLabel: NSTextField
    public var seconColumnLabel: NSTextField
    public var closeButonView: CloseButtonView
    
    let contentView = NSView()
    
    private var swipeActionViewLeadingConstraint = NSLayoutConstraint()
    private var contentViewTrailingConstraint = NSLayoutConstraint()
    private var isRunningFullSwipe = false
    private var isRunningPartialFullSwipe = false
    
    private var totalSwipeDistance: CGFloat = 0
    
    /// need to lock on swipe-to-close-tab scroll and avoid letting user to swipe vertically
    private var isUserTryingToSwipeToCloseTab = false
    
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
        
        self.closeButonView = CloseButtonView(tab: tab)
        let swipeActionView = makeSwipeActionView()
        let textLabelForSwipeView = NSTextField(labelWithString: "Swipe to close tab")
        let stackView = NSStackView()
        let faviconView = FaviconView(tab: tab)
        
        super.init(frame: .zero)
        
        self.clipsToBounds = true
        self.wantsLayer = true
        self.layer?.cornerRadius = 4
        
        self.closeButonView.isHidden = true
        
        
        contentView.wantsLayer = true
        
        swipeActionView.layer?.cornerRadius = SwipeActionConfig.cornerRadius
        
        
        textLabelForSwipeView.font = .systemFont(ofSize: 13, weight: .regular)
        textLabelForSwipeView.textColor = .white
        
        self.addSubview(swipeActionView)
        swipeActionView.addSubview(textLabelForSwipeView)
        self.addSubview(contentView)
        contentView.addSubview(stackView)
        contentView.addSubview(faviconView)
        contentView.addSubview(closeButonView)
        
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
        
        swipeActionViewLeadingConstraint = swipeActionView.leadingAnchor.constraint(equalTo: self.trailingAnchor, constant: 10)
        contentViewTrailingConstraint = contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        textLabelForSwipeView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            swipeActionViewLeadingConstraint,
            swipeActionView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 10),
            swipeActionView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            swipeActionView.heightAnchor.constraint(equalTo: self.heightAnchor),
            
            textLabelForSwipeView.centerYAnchor.constraint(equalTo: swipeActionView.centerYAnchor),
            textLabelForSwipeView.centerXAnchor.constraint(equalTo: swipeActionView.centerXAnchor),
            
            contentViewTrailingConstraint,
            contentView.widthAnchor.constraint(equalTo: self.widthAnchor),
            contentView.topAnchor.constraint(equalTo: self.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            faviconView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 21),
            faviconView.widthAnchor.constraint(equalToConstant: faviconView.width),
            faviconView.heightAnchor.constraint(equalToConstant: faviconView.height),
            faviconView.centerYAnchor.constraint(equalTo: stackView.centerYAnchor),
            
            closeButonView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            closeButonView.widthAnchor.constraint(equalToConstant: tabHeight),
            closeButonView.heightAnchor.constraint(equalToConstant: tabHeight),
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
    
    override func mouseMoved(with event: NSEvent) {
        onTabHover?(tab.renderIndex)
        closeButonView.isHidden = false
    }
    
    override func scrollWheel(with event: NSEvent) {
        
        if isRunningFullSwipe {
            super.scrollWheel(with: event)
            return
        }
        
        if isItVerticalScroll(event) && !isUserTryingToSwipeToCloseTab {
            performFullSwipeToRight()
            super.scrollWheel(with: event)
            return
        }
        
        isUserTryingToSwipeToCloseTab = true
        
        setTotalSwipeDistance(currentScrollingDeltaX: event.scrollingDeltaX)
        
        if event.phase != .changed {
            if self.totalSwipeDistance < -SwipeActionConfig.fullSwipeThreshold {
                performFullSwipeToLeft()
                
            } else {
                
                if self.totalSwipeDistance < -SwipeActionConfig.partialRightSwipeThreshold {
                    performPartialSwipeToRight()
                } else {
                    performFullSwipeToRight()
                }
                
            }
            return
        }
        
        var distance: CGFloat = self.totalSwipeDistance
        
        if distance < -SwipeActionConfig.fullSwipeThreshold {

            if !isRunningPartialFullSwipe {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            
            isRunningPartialFullSwipe = true
            distance -= 300
            
        } else {
            if isRunningPartialFullSwipe {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            
            isRunningPartialFullSwipe = false
        }
        
        if distance < -tabContentViewWidth {
            distance = -tabContentViewWidth
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            
            self.swipeActionViewLeadingConstraint.animator().constant = distance
            self.contentViewTrailingConstraint.animator().constant = distance - SwipeActionConfig.spacing
        }

    }
    
    override func mouseExited(with event: NSEvent) {
        closeButonView.isHidden = true
        isUserTryingToSwipeToCloseTab = false
    }
    
    private func setTotalSwipeDistance(currentScrollingDeltaX: CGFloat) {
        var distance: CGFloat = 0
        
        distance = totalSwipeDistance + currentScrollingDeltaX
        
        if distance > 0 {
            distance = 0
            return
        }
        if distance < -tabContentViewWidth {
            distance = -tabContentViewWidth
            return
        }
        
        totalSwipeDistance = distance
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.addTrackingArea(NSTrackingArea(rect: self.contentView.bounds, options: options, owner: self, userInfo: nil))
    }
    
    private func isItVerticalScroll(_ event: NSEvent) -> Bool {
        return abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)
    }
    
    private func performFullSwipeToLeft() {
        isRunningFullSwipe = true
        self.totalSwipeDistance = 0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1

            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            self.swipeActionViewLeadingConstraint.animator().constant = -tabContentViewWidth
            self.contentViewTrailingConstraint.animator().constant = -tabContentViewWidth
        } completionHandler: {
            self.onTabClose?(self.tab.id)
        }
    }
    
    private func performPartialSwipeToRight() {
        isUserTryingToSwipeToCloseTab = false
        isRunningPartialFullSwipe = false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            
            self.swipeActionViewLeadingConstraint.animator().constant = -SwipeActionConfig.partialRightSwipeThreshold + SwipeActionConfig.spacing
            self.contentViewTrailingConstraint.animator().constant = -SwipeActionConfig.partialRightSwipeThreshold
        } completionHandler: {
            self.totalSwipeDistance = -SwipeActionConfig.partialRightSwipeThreshold
        }
    }
    
    private func performFullSwipeToRight() {
        isUserTryingToSwipeToCloseTab = false
        isRunningPartialFullSwipe = false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            
            self.swipeActionViewLeadingConstraint.animator().constant = SwipeActionConfig.spacing
            self.contentViewTrailingConstraint.animator().constant = 0
        } completionHandler: {
            self.totalSwipeDistance = 0
        }
    }
}
