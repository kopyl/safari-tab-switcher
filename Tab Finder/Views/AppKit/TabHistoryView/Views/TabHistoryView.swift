import Cocoa

let tabHeight: CGFloat = 57
private let tabSpacing: CGFloat = 0
private let tabBottomPadding: CGFloat = 4
private let tabInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
private let headerHeight: CGFloat = 73

let tabContentViewWidth = tabsPanelWidth - tabInsets.left - tabInsets.right

class TabHistoryView: NSViewController {
    private var scrollView: NSScrollView!
    private var tabsContainerView: NSView!
    private var textView: NSTextField!
    private var pinButtonView: NSButton!
    private var tintView: NSView!
    private var openTabsHeaderView = TabsHeaderView(title: "Open", height: nil)
    private var closedTabsHeaderView = TabsHeaderView(title: "History", height: 95, topInset: 14)
    
    private var localKeyboardEventMonitor: Any?
    private var globalMouseDownEventMonitor: Any?
    
    private var scrollObserver: NSObjectProtocol?
    
    private var visibleTabViews: [Int: TabItemView] = [:]
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: tabsPanelWidth, height: tabsPanelHeight))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backgroundBlurView = makeBackgroundBlurView()
        let searchIconView = makeSearchIconView()
        let headerView = makeHeaderView()
        
        scrollView = makeScrollView()
        tintView = makeColorView()
        tabsContainerView = FlippedView()
        textView = makeTextFieldView()
        pinButtonView = makePinButtonView(
            isFilled: appState.isTabsSwitcherNeededToStayOpen,
            action: #selector(togglePin)
        )
        
        tabsContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(backgroundBlurView)
        view.addSubview(tintView)
        view.addSubview(headerView)
        view.addSubview(scrollView)

        headerView.addSubview(searchIconView)
        headerView.addSubview(textView)
        headerView.addSubview(pinButtonView)
        
        scrollView.documentView = tabsContainerView
        scrollView.hasVerticalScroller = true
        
        NSLayoutConstraint.activate([
            backgroundBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tintView.topAnchor.constraint(equalTo: view.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),
            
            searchIconView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 68),
            searchIconView.heightAnchor.constraint(equalToConstant: headerHeight),
            searchIconView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 2),
            
            pinButtonView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            pinButtonView.widthAnchor.constraint(equalToConstant: 66),
            pinButtonView.heightAnchor.constraint(equalToConstant: headerHeight),
            pinButtonView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 2),
            
            textView.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: -9),
            textView.trailingAnchor.constraint(equalTo: pinButtonView.leadingAnchor),
            textView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 2),
            
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tabsContainerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        #if LITE
            scrollView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -adButtonHeight-tabBottomPadding
            ).isActive = true
        #else
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        #endif

        #if LITE
            let adButtonView = AdButtonView()
            view.addSubview(adButtonView)
        
            NSLayoutConstraint.activate([
                adButtonView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -tabBottomPadding),
                adButtonView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: tabInsets.left),
                adButtonView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -tabInsets.right),
                adButtonView.heightAnchor.constraint(equalToConstant: adButtonHeight)
            ])
        #endif
        
        setTabsPanelBorderRadius()
        
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
            self,
            selector: #selector(handleInputSourceChange),
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(reactOnTabCloseNotificationFromSafari),
            name: Notifications.tabClosed,
            object: nil
        )
    }
    
    @objc func reactOnTabCloseNotificationFromSafari(_ notification: Notification) {
        guard let object = notification.object as? String else { return }
        guard let tabIdRemoved = Int(object) else { return }
        guard let tabIndex = appState.renderedTabs.firstIndex(where: { $0.id == tabIdRemoved }) else { return}
        guard let tabViewToRemove = visibleTabViews[tabIndex] else { return }
        
        if appState.indexOfTabToSwitchTo >= appState.renderedTabs.count - 1 {
            appState.indexOfTabToSwitchTo = max(0, appState.renderedTabs.count - 2)
        }
        
        appState.renderedTabs = appState.renderedTabs.filter { $0.id != tabIdRemoved }
        appState.savedOpenTabs = appState.savedOpenTabs.filter { $0.id != tabIdRemoved }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            
            tabViewToRemove.swipeActionViewCenterYAnchorConstraint.animator().constant = -tabHeight
            
            for (idx, otherTabView) in visibleTabViews {
                if idx > tabIndex {
                    let currentFrame = otherTabView.frame
                    otherTabView.animator().frame = NSRect(
                        x: currentFrame.origin.x,
                        y: currentFrame.origin.y - (tabHeight + tabSpacing),
                        width: currentFrame.width,
                        height: currentFrame.height
                    )
                }
            }
            
        }, completionHandler: {
            tabViewToRemove.removeFromSuperview()
            self.visibleTabViews.removeValue(forKey: tabIndex)
            
            let totalHeight = CGFloat(appState.renderedTabs.count) * (tabHeight + tabSpacing) - tabSpacing
            self.tabsContainerView.frame.size.height = totalHeight + tabBottomPadding
            
            appState.savedOpenTabs = Store.windows.windows.last?.tabs.tabs ?? Tabs().tabs
            appState.savedClosedTabs = Store.VisitedPagesHistory.loadAll()
            prepareTabsForRender()
            self.renderTabs()
            
            self.updateSearchFieldPlaceholderText()
            self.updateTabsHeaderViews()
            if appState.savedOpenTabs.count == 0 {
                hideTabsPanel()
            }
        })
    }
    
    @objc func handleInputSourceChange(notification: Notification) {
        appState.currentInputSourceName = getCurrentInputSourceName()
        self.updateSearchFieldPlaceholderText()
    }
    
    @objc private func textDidChange(_ notification: Notification) {
        let text = textView.stringValue
        appState.searchQuery = text
        prepareTabsForRender()
        
        if appState.sortTabsBy == .lastSeen {
            if text.isEmpty {
                setIndexOfTabToSwitchToForEmptyTexField()
            }
            else {
                appState.indexOfTabToSwitchTo = 0
            }
        }
        else {
            appState.indexOfTabToSwitchTo = 0
        }
        
        scrollToTop()
        
        DispatchQueue.main.async {
            self.updateTabsHeaderViews()
            self.renderTabs()
        }
    }
    
    @objc func togglePin() {
        appState.isTabsSwitcherNeededToStayOpen.toggle()
        pinButtonView.image = makePinImage(isFilled: appState.isTabsSwitcherNeededToStayOpen)
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
        updateTabsHeaderViews()
        self.renderTabs()
        self.textView.stringValue = ""
        pinButtonView.image = makePinImage(isFilled: appState.isTabsSwitcherNeededToStayOpen)
        updateSearchFieldPlaceholderText()
        applyBackgroundTint()
    }
    
    override func viewDidDisappear() {
        clearAllTabViews()
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
    
    public func updateSearchFieldPlaceholderText() {
        textView.placeholderString = getSearchFieldPlaceholderText(by: appState.currentInputSourceName, tabsCount: appState.savedOpenTabs.count)
    }
    
    public func updateTabsHeaderViews() {
        openTabsHeaderView.tabsCount = appState.openTabsRenderedCount
        closedTabsHeaderView.tabsCount = appState.closedTabsRenderedCount
        
        if appState.openTabsRenderedCount == 0 && appState.closedTabsRenderedCount > 0 {
            closedTabsHeaderView.shiftInnerConterY(by: 0)
            closedTabsHeaderView.frame.size.height = closedTabsHeaderView.standardHeaderHeight
            closedTabsHeaderView.height = closedTabsHeaderView.standardHeaderHeight
        }
        else {
            closedTabsHeaderView.shiftInnerConterY(by: closedTabsHeaderView.topInset)
            closedTabsHeaderView.frame.size.height = closedTabsHeaderView.initHeight
            closedTabsHeaderView.height = closedTabsHeaderView.initHeight
        }
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
        tabsContainerView.subviews.forEach { $0.removeFromSuperview() }
        visibleTabViews.removeAll()
    }
    
    public func renderTabs() {
        clearAllTabViews()

        let totalHeight = CGFloat(appState.renderedTabs.count) * (tabHeight + tabSpacing) - tabSpacing
        tabsContainerView.frame.size.height = totalHeight + tabBottomPadding + openTabsHeaderView.height + closedTabsHeaderView.height
        
        tabsContainerView.addSubview(openTabsHeaderView)

        updateVisibleTabViews()
    }
    
    private func updateVisibleTabViews() {
        guard !appState.renderedTabs.isEmpty else { return }

        let visibleRect = scrollView.contentView.bounds
        let expandedRect = NSRect(
            x: visibleRect.minX,
            y: max(0, visibleRect.minY - tabHeight * 2),
            width: visibleRect.width,
            height: visibleRect.height + tabHeight * 4
        )

        let yOffset = max(0, expandedRect.minY - openTabsHeaderView.height)

        var firstVisibleIndex = max(0, Int(yOffset / (tabHeight + tabSpacing)))
        let lastVisibleIndex = min(
            appState.renderedTabs.count - 1,
            Int((expandedRect.maxY - openTabsHeaderView.height) / (tabHeight + tabSpacing))
        )
        
        if firstVisibleIndex > lastVisibleIndex {
            /// to prevent app from crashing when a user is swiping the list of tabs with great force
            firstVisibleIndex = lastVisibleIndex
        }
        
        let visibleIndexSet = Set(firstVisibleIndex...lastVisibleIndex)

        for (index, view) in visibleTabViews {
            if !visibleIndexSet.contains(index) {
                view.removeFromSuperview()
                visibleTabViews.removeValue(forKey: index)
            }
        }

        var closedHeaderInserted = false

        for index in firstVisibleIndex...lastVisibleIndex {
            guard visibleTabViews[index] == nil else { continue }

            let tab = appState.renderedTabs[index]
            let tabView = createTabView(for: tab, at: index)

            // Add the closed header view BEFORE adding the first closed tab
            if index == appState.openTabsRenderedCount && !closedHeaderInserted {
                closedTabsHeaderView.frame = NSRect(
                    x: 0,
                    y: tabView.frame.minY - tabSpacing - closedTabsHeaderView.height,
                    width: tabsContainerView.frame.width,
                    height: closedTabsHeaderView.height
                )
                tabsContainerView.addSubview(closedTabsHeaderView)
                closedHeaderInserted = true
            }

            tabsContainerView.addSubview(tabView)
            visibleTabViews[index] = tabView
        }

        updateHighlighting()
    }
    
    // Create a tab view at the specified index
    private func createTabView(for tab: Tab, at index: Int) -> TabItemView {
        let tabView = TabItemView(tab: tab)
        
        // Calculate Y position based on index
        var yPos = CGFloat(index) * (tabHeight + tabSpacing) + openTabsHeaderView.height

        /// shift the tab view down by the height of the header
        if index > appState.openTabsRenderedCount-1 {
            yPos += closedTabsHeaderView.height
        }
        
        tabView.frame = NSRect(
            x: tabInsets.left,
            y: yPos,
            width: tabsContainerView.frame.width - tabInsets.left - tabInsets.right,
            height: tabHeight
        )
        
        tabView.onTabHover = { [weak self] renderIndex in
            appState.indexOfTabToSwitchTo = renderIndex
            self?.updateHighlighting()
        }
        
        tabView.onTabClose = { tabId in
            guard let tab = appState.renderedTabs.first(where: { $0.id == tabId }) else { return }
            Task {
                await closeTab(tab: tab)
            }
        }
        
        updateHighlighting()
        
        return tabView
    }
    
    private func updateHighlighting() {
        for (_, tabView) in visibleTabViews {
            tabView.updateHighlighting()
        }
    }
    
    private func scrollToHistoryTopWithoutAnimation() {
        let index = appState.openTabsRenderedCount
        guard index >= 0 && index < appState.renderedTabs.count else { return }
        var yPos = CGFloat(index) * (tabHeight + tabSpacing) + openTabsHeaderView.height
        yPos += closedTabsHeaderView.height
        
        if visibleTabViews[index] == nil {
            let tabView = createTabView(for: appState.renderedTabs[index], at: index)
            tabsContainerView.addSubview(tabView)
            visibleTabViews[index] = tabView
        }
        
        DispatchQueue.main.async {
            appState.indexOfTabToSwitchTo = appState.openTabsRenderedCount
            self.updateVisibleTabViews()
            self.updateHighlighting()
            
            if index == 0 {
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            }
            else {
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: yPos - self.openTabsHeaderView.height))
            }

            self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
        }
    }
    
    private func scrollToSelectedTabWithoutAnimation() {
        let index = appState.indexOfTabToSwitchTo
        guard index >= 0 && index < appState.renderedTabs.count else { return }

        var yPos = CGFloat(index) * (tabHeight + tabSpacing) + openTabsHeaderView.height
        
        // ⬅️ add closed header height if this tab is in "Closed" section
        if index > appState.openTabsRenderedCount - 1 {
            yPos += closedTabsHeaderView.height
        }

        if visibleTabViews[index] == nil {
            let tabView = createTabView(for: appState.renderedTabs[index], at: index)
            tabsContainerView.addSubview(tabView)
            visibleTabViews[index] = tabView
        }

        DispatchQueue.main.async {
            self.updateVisibleTabViews()
            self.updateHighlighting()
            let visibleRect = self.scrollView.contentView.bounds
            
            if index == 0 {
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            }

            else if yPos < visibleRect.minY {
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: yPos))
            } else if yPos + tabHeight > visibleRect.maxY {
                self.scrollView.contentView.scroll(to: NSPoint(x: 0, y: yPos + tabHeight - visibleRect.height + tabBottomPadding))
            }

            self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
        }
    }
    
    private func scrollToTop() {
        scrollView.contentView.scrollToVisible(NSRect(x: 0, y: 0, width: scrollView.frame.width, height: 1))
    }
    
    func handleNavigationKeyPresses(event: NSEvent) {
        guard let key = NavigationKeys(rawValue: event.keyCode) else { return }
        
        switch key {
        case .arrowUp, .backTick:
            guard !appState.renderedTabs.isEmpty else { return }
            appState.indexOfTabToSwitchTo -= 1
            scrollToSelectedTabWithoutAnimation()
        case .tab:
            guard !appState.renderedTabs.isEmpty else { return }
            if event.modifierFlags.contains(.shift) {
                appState.indexOfTabToSwitchTo -= 1
            } else {
                appState.indexOfTabToSwitchTo += 1
            }
            scrollToSelectedTabWithoutAnimation()
        case .arrowDown:
            guard !appState.renderedTabs.isEmpty else { return }
            appState.indexOfTabToSwitchTo += 1
            scrollToSelectedTabWithoutAnimation()
        case .return:
            guard !appState.renderedTabs.isEmpty else { return }
            hideTabsPanelAndSwitchTabs()
        case .escape:
            hideTabsPanel(withoutAnimation: true)
        }
    }
    
    func handleAppShortcutKeyPresses(event: NSEvent) {
        guard let key = AppShortcutKeys(rawValue: event.keyCode) else { return }
        
        switch key {
        case .a:
            NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self)
        case .z:
            if event.shiftIsHolding {
                NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
                return
            }
            NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
        case .x:
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case .c:
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case .v:
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            
        case .w:
            let tabToClose = appState.renderedTabs[appState.indexOfTabToSwitchTo]
            
            guard let tab = appState.renderedTabs.first(where: { $0.id == tabToClose.id }) else { return }
            Task {
                await closeTab(tab: tab)
            }
        case .p:
            togglePin()
        case .h:
            scrollToHistoryTopWithoutAnimation()
        case .o:
            appState.indexOfTabToSwitchTo = 0
            scrollToTop()
            updateHighlighting()
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
                
                if event.appShortcutIsPressed {
                    self?.handleAppShortcutKeyPresses(event: event)
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
    
    private func setTabsPanelBorderRadius() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        
        /// without this corner radius is not set on macOS 13.0. On 15.0 it works without masksToBounds
        view.layer?.masksToBounds = true
    }
    
    deinit {
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
