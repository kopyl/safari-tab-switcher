import Cocoa

class AppKitTabHistoryView: NSViewController {
    private var scrollView: NSScrollView!
    private var tabsContainer: NSView!
    private var mainStackView: NSStackView!
    private var textView: NSTextField!
    
    private var localKeyboardEventMonitor: Any?
    private var globalMouseDownEventMonitor: Any?
    private var scrollObserver: NSObjectProtocol?
    
    private var allTabs: [Tab] = []
    private var visibleTabViews: [Int: NSView] = [:]
    
    private let tabHeight: CGFloat = 57
    private let tabSpacing: CGFloat = 0
    private let tabBottomPadding: CGFloat = 4
    private let tabInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let visualEffectView = makeVisualEffectView()
        scrollView = makeScrollView()
        tabsContainer = FlippedView()
        mainStackView = makeStackView()
        textView = makeTextField()
        
        tabsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(visualEffectView)
        view.addSubview(mainStackView)
        mainStackView.addArrangedSubview(textView)
        mainStackView.addArrangedSubview(scrollView)
        
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = tabsContainer
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: view.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        tabsContainer.frame = CGRect(origin: .zero, size: CGSize(width: 792, height: 0))
        
        setBorderRadius()
        setupKeyEventMonitor()
        setupMouseDownEventMonitor()
        setupScrollObserver()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: textView
        )
    }
    
    private func setupScrollObserver() {
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: nil
        ) { [weak self] _ in
            self?.updateVisibleTabViews()
        }
    }
    
    @objc private func textDidChange(_ notification: Notification) {
        let text = textView.stringValue
        appState.searchQuery = text
        rerenderTabs()
        appState.indexOfTabToSwitchTo = text.isEmpty ? 1 : 0
        if !text.isEmpty {
            scrollToTop()
        }
        DispatchQueue.main.async {
            self.renderTabs()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        scrollToTop()
    }
    
    override func viewWillAppear() {
        self.renderTabs()
        self.textView.stringValue = ""
    }
    
    override func viewDidDisappear() {
        clearAllTabViews()
    }
    
    private func clearAllTabViews() {
        tabsContainer.subviews.forEach { $0.removeFromSuperview() }
        visibleTabViews.removeAll()
    }
    
    private func renderTabs() {
        clearAllTabViews()
        allTabs = appState.renderedTabs
        
        let totalHeight = CGFloat(allTabs.count) * (tabHeight + tabSpacing) - tabSpacing
        tabsContainer.frame.size.height = totalHeight + self.tabBottomPadding
        
        updateVisibleTabViews()
    }
    
    private func updateVisibleTabViews() {
        guard !allTabs.isEmpty else { return }
        
        // Get the visible rect of the scroll view
        let visibleRect = scrollView.contentView.bounds
        
        // Expand the visible rect to include some off-screen items for smooth scrolling
        let expandedRect = NSRect(
            x: visibleRect.minX,
            y: max(0, visibleRect.minY - tabHeight * 2),
            width: visibleRect.width,
            height: visibleRect.height + tabHeight * 4
        )
        
        // Calculate visible index range
        let firstVisibleIndex = max(0, Int(expandedRect.minY / (tabHeight + tabSpacing)))
        let lastVisibleIndex = min(
            allTabs.count - 1,
            Int(expandedRect.maxY / (tabHeight + tabSpacing))
        )
        
        // Remove views that are no longer visible
        let visibleIndexSet = Set(firstVisibleIndex...lastVisibleIndex)
        
        // Remove tab views that are no longer visible
        for (index, view) in visibleTabViews {
            if !visibleIndexSet.contains(index) {
                view.removeFromSuperview()
                visibleTabViews.removeValue(forKey: index)
            }
        }
        
        // Add missing visible tab views
        for index in firstVisibleIndex...lastVisibleIndex {
            if visibleTabViews[index] == nil {
                
                let tabView = createTabView(for: allTabs[index], at: index)
                tabView.onTabHover = { [weak self] renderIndex in
                    appState.indexOfTabToSwitchTo = renderIndex
                    self?.updateHighlighting()
                }
                
                tabsContainer.addSubview(tabView)
                visibleTabViews[index] = tabView
            }
        }
    }
    
    // Create a tab view at the specified index
    private func createTabView(for tab: Tab, at index: Int) -> AppKitTabItemView {
        let tabView = AppKitTabItemView(tab: tab)
        
        // Calculate Y position based on index
        let yPos = CGFloat(index) * (tabHeight + tabSpacing)
        
        tabView.frame = NSRect(
            x: tabInsets.left,
            y: yPos,
            width: tabsContainer.frame.width,
            height: tabHeight
        )
        
        updateHighlighting()
        
        tabView.widthAnchor.constraint(equalToConstant: tabsContainer.frame.width).isActive = true
        tabView.heightAnchor.constraint(equalToConstant: tabHeight).isActive = true
        return tabView
    }
    
    private func updateHighlighting() {
        for (idx, tabView) in visibleTabViews {
            if idx == appState.indexOfTabToSwitchTo {
                tabView.wantsLayer = true
                tabView.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.3).cgColor
                tabView.layer?.cornerRadius = 6
            } else {
                tabView.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
    
    private func scrollToSelectedTabWithoutAnimation() {
        let index = appState.indexOfTabToSwitchTo
        guard index >= 0 && index < allTabs.count else { return }
        
        // Calculate the rect for the selected tab
        let yPos = CGFloat(index) * (tabHeight + tabSpacing)
        let tabRect = NSRect(x: 0, y: yPos, width: tabsContainer.frame.width, height: tabHeight)
        
        // Make sure the tab view for selected tab exists
        if visibleTabViews[index] == nil {
            let tabView = createTabView(for: allTabs[index], at: index)
            tabsContainer.addSubview(tabView)
            visibleTabViews[index] = tabView
        }
        
        updateHighlighting()
        
        DispatchQueue.main.async {
            let visibleRect = self.scrollView.contentView.bounds
            
            if tabRect.minY < visibleRect.minY {
                self.scrollView.contentView.bounds.origin.y = tabRect.minY
            } else if tabRect.maxY > visibleRect.maxY {
                self.scrollView.contentView.bounds.origin.y = tabRect.maxY - visibleRect.height + self.tabBottomPadding
            }
        }
    }
    
    private func scrollToTop() {
        scrollView.contentView.scrollToVisible(NSRect(x: 0, y: 0, width: scrollView.frame.width, height: 1))
    }
    
    func handleNavigationKeyPresses(event: NSEvent) {
        let isTabsSwitcherNeededToStayOpen = appState.isTabsSwitcherNeededToStayOpen
        
        guard isUserHoldingShortcutModifiers(event: event) || isTabsSwitcherNeededToStayOpen else { return }
        guard !allTabs.isEmpty else { return }
        guard let key = NavigationKeys(rawValue: event.keyCode) else { return }
        
        switch key {
        case .arrowUp, .backTick:
            appState.indexOfTabToSwitchTo -= 1
            scrollToSelectedTabWithoutAnimation()
        case .tab:
            if event.modifierFlags.contains(.shift) {
                appState.indexOfTabToSwitchTo -= 1
            } else {
                appState.indexOfTabToSwitchTo += 1
            }
            scrollToSelectedTabWithoutAnimation()
        case .arrowDown:
            appState.indexOfTabToSwitchTo += 1
            scrollToSelectedTabWithoutAnimation()
        case .return:
            hideTabsPanelAndSwitchTabs()
        case .escape:
            hideTabsPanel(withoutAnimation: true)
        }
    }
    
    func handleKeyRelease(event: NSEvent) {
        let isTabsSwitcherNeededToStayOpen = appState.isTabsSwitcherNeededToStayOpen
        
        guard isTabsSwitcherNeededToStayOpen == false else { return }
        guard !isUserHoldingShortcutModifiers(event: event) else { return }
        hideTabsPanelAndSwitchTabs()
    }
    
    private func setupKeyEventMonitor() {
        localKeyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard NSApp.keyWindow?.identifier == tabsPanelID else { return event }
            
            if event.type == .keyDown {
                if NavigationKeys(rawValue: event.keyCode) != nil {
                    self?.handleNavigationKeyPresses(event: event)
                    return nil
                }
                
            } else if event.type == .flagsChanged {
                self?.handleKeyRelease(event: event)
            }
            return event
        }
    }

    private func setupMouseDownEventMonitor() {
        globalMouseDownEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { event in
            if appState.isTabsPanelOpen {
                hideTabsPanel(withoutAnimation: true)
            }
        }
    }
    
    private func setBorderRadius() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        
        /// without this corner radius is not set on macOS 13.0. On 15.0 it works without masksToBounds
        view.layer?.masksToBounds = true
    }
    
    deinit {
        if let scrollObserver = scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

final class AppKitTabItemView: NSStackView {
    let tab: Tab
    var onTabHover: ((Int) -> Void)?
    
    init(tab: Tab) {
        self.tab = tab
        super.init(frame: .zero)

        let titleLabel = NSTextField(labelWithString: tab.host)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let hostLabel = NSTextField(labelWithString: tab.title)
        hostLabel.lineBreakMode = .byTruncatingTail
        hostLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        self.orientation = .horizontal
        self.spacing = 8
        self.distribution = .fillEqually
        self.addArrangedSubview(titleLabel)
        self.addArrangedSubview(hostLabel)
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
    }
}
