import Cocoa

private let tabHeight: CGFloat = 57
private let tabSpacing: CGFloat = 0
private let tabBottomPadding: CGFloat = 4
private let tabInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
private let headerHeight: CGFloat = 72

class TabHistoryView: NSViewController {
    private var scrollView: NSScrollView!
    private var tabsContainer: NSView!
    private var mainStackView: NSStackView!
    private var textView: NSTextField!
    private var pinButton: NSButton!
    private var tintView: NSView!
    
    private var localKeyboardEventMonitor: Any?
    private var globalMouseDownEventMonitor: Any?
    
    private var scrollObserver: NSObjectProtocol?
    
    private var allTabs: [Tab] = []
    private var visibleTabViews: [Int: TabItemView] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let visualEffectView = makeVisualEffectView()
        let searchIcon = makeSearchIcon()
        let headerView = makeHeaderView()
        
        scrollView = makeScrollView()
        tintView = makeColorView(hex: appState.userSelectedAccentColor)
        tabsContainer = FlippedView()
        textView = makeTextField()
        pinButton = makePinButton(
            isFilled: appState.isTabsSwitcherNeededToStayOpen,
            action: #selector(togglePin)
        )
        
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tabsContainer.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(visualEffectView)
        view.addSubview(tintView)
        view.addSubview(headerView)
        view.addSubview(scrollView)

        headerView.addSubview(searchIcon)
        headerView.addSubview(textView)
        headerView.addSubview(pinButton)
        
        scrollView.documentView = tabsContainer
        scrollView.hasVerticalScroller = true
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tintView.topAnchor.constraint(equalTo: view.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),
            
            searchIcon.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 74),
            searchIcon.heightAnchor.constraint(equalToConstant: headerHeight),
            searchIcon.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            pinButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            pinButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            pinButton.widthAnchor.constraint(equalToConstant: 74),
            pinButton.heightAnchor.constraint(equalToConstant: headerHeight),
            
            textView.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: -14),
            textView.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor),
            textView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tabsContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
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
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                appState.currentInputSourceName = getCurrentInputSourceName()
                self?.textView.placeholderString = getSearchFieldPlaceholderText(
                    by: appState.currentInputSourceName,
                    tabsCount: appState.savedTabs.count
                )
            }
        }
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
    
    @objc func togglePin() {
        appState.isTabsSwitcherNeededToStayOpen.toggle()
        pinButton.image = makePinImage(isFilled: appState.isTabsSwitcherNeededToStayOpen)
        Store.isTabsSwitcherNeededToStayOpen = appState.isTabsSwitcherNeededToStayOpen
        
        if !appState.isTabsSwitcherNeededToStayOpen {
            guard !isUserHoldingShortcutModifiers() else { return }
            hideTabsPanel()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        scrollToTop()
    }
    
    override func viewWillAppear() {
        self.renderTabs()
        self.textView.stringValue = ""
        pinButton.image = makePinImage(isFilled: appState.isTabsSwitcherNeededToStayOpen)
        textView.placeholderString = getSearchFieldPlaceholderText(by: appState.currentInputSourceName, tabsCount: appState.savedTabs.count)
        applyBackgroundTint()
    }
    
    override func viewDidDisappear() {
        clearAllTabViews()
    }
    
    private func applyBackgroundTint() {
        if appState.userSelectedAccentColor == Store.userSelectedAccentColorDefaultValue {
            tintView.isHidden = true
        } else {
            tintView.isHidden = false
            tintView.layer?.backgroundColor = hexToColor(appState.userSelectedAccentColor).cgColor
        }
    }
    
    private func clearAllTabViews() {
        tabsContainer.subviews.forEach { $0.removeFromSuperview() }
        visibleTabViews.removeAll()
    }
    
    private func renderTabs() {
        clearAllTabViews()
        allTabs = appState.renderedTabs
        
        let totalHeight = CGFloat(allTabs.count) * (tabHeight + tabSpacing) - tabSpacing
        tabsContainer.frame.size.height = totalHeight + tabBottomPadding
        
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
        
        /// without this, the first tab does not get highlighted when it's the only tab left in search results
        updateHighlighting()
    }
    
    // Create a tab view at the specified index
    private func createTabView(for tab: Tab, at index: Int) -> TabItemView {
        let tabView = TabItemView(tab: tab)
        
        // Calculate Y position based on index
        let yPos = CGFloat(index) * (tabHeight + tabSpacing)
        
        tabView.frame = NSRect(
            x: tabInsets.left,
            y: yPos,
            width: tabsContainer.frame.width - tabInsets.left - tabInsets.right,
            height: tabHeight
        )
        
        updateHighlighting()
        
        return tabView
    }
    
    private func updateHighlighting() {
        for (idx, tabView) in visibleTabViews {
            if idx == appState.indexOfTabToSwitchTo {
                tabView.wantsLayer = true
                tabView.layer?.backgroundColor = NSColor.currentTabBg.cgColor
                tabView.layer?.cornerRadius = 6
                tabView.hostLabel.textColor = .currentTabFg
                tabView.titleLabel.textColor = .currentTabFg
            } else {
                tabView.layer?.backgroundColor = NSColor.clear.cgColor
                tabView.hostLabel.textColor = .tabFg
                tabView.titleLabel.textColor = .tabFg
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
                self.scrollView.contentView.bounds.origin.y = tabRect.maxY - visibleRect.height + tabBottomPadding
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

final class TabItemView: NSView {
    let tab: Tab
    var onTabHover: ((Int) -> Void)?
    
    public var hostLabel: NSTextField
    public var titleLabel: NSTextField
    
    init(tab: Tab) {
        self.tab = tab

        self.hostLabel = NSTextField(labelWithString: tab.host)
        self.titleLabel = NSTextField(labelWithString: tab.title)
        super.init(frame: .zero)
        if tab.host == "" {
            hostLabel.stringValue = "No title"
        }
        hostLabel.lineBreakMode = .byTruncatingTail
        hostLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostLabel.font = .systemFont(ofSize: 18)
        hostLabel.textColor = .tabFg

        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .tabFg
        
        let stackView: NSStackView = .init()

        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.edgeInsets = .init(top: 0, left: 57, bottom: 0, right: 50)
        stackView.addArrangedSubview(hostLabel)
        stackView.addArrangedSubview(titleLabel)
        
        let faviconView = FaviconView(tab: tab)

        self.addSubview(faviconView)
        self.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            faviconView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 21),
            faviconView.widthAnchor.constraint(equalToConstant: faviconView.width),
            faviconView.heightAnchor.constraint(equalToConstant: faviconView.height),
            faviconView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: self.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
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
