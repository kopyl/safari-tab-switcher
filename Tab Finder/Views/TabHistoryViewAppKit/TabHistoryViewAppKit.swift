import SwiftUI

class AppKitTabHistoryView: NSViewController {
    private var scrollView: NSScrollView!
    private var tabsStackView: NSStackView!
    private var mainStackView: NSStackView!
    private var textView: NSTextField!
    
    private var localEventMonitor: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let visualEffectView = makeVisualEffectView()
        scrollView = makeScrollView()
        tabsStackView = makeStackView()
        mainStackView = makeStackView()
        textView = makeTextField()

        view.addSubview(visualEffectView)
        view.addSubview(mainStackView)
        mainStackView.addArrangedSubview(textView)
        mainStackView.addArrangedSubview(scrollView)
        
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        let flippedView = FlippedView()
        flippedView.translatesAutoresizingMaskIntoConstraints = false
        flippedView.addSubview(tabsStackView)

        scrollView.documentView = flippedView

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
        
        setBorderRadius()
        
        setupKeyEventMonitor()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: textView
        )
    }
    
    @objc private func textDidChange(_ notification: Notification) {
        let text = textView.stringValue
        appState.searchQuery = text
        rerenderTabs()
        appState.indexOfTabToSwitchTo = text.isEmpty ? 1 : 0
        if !text.isEmpty {
            scrollToTop()
        }
        renderTabs()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        scrollToTop()
    }
    
    override func viewWillAppear() {
        self.renderTabs()
        self.textView.stringValue = ""
    }
    
    private func renderTabs() {
        tabsStackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for tab in appState.renderedTabs {
            let tabView = NSHostingView(rootView: TabItemView(tab: tab))
            tabsStackView?.addArrangedSubview(tabView)
            
            NSLayoutConstraint.activate([
                tabView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 4),
                tabView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -4),
            ])
        }

        let fittingHeight = tabsStackView?.fittingSize.height ?? 0
        scrollView.documentView?.frame.size.height = fittingHeight
    }
    
    private func setupKeyEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
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
    
    private func scrollToSelectedTabWithoutAnimation() {
        /// https://kopyl.gitbook.io/tab-finder/appkit-rewrite/features/scrolling/current-implementation-specifics

        let index = appState.indexOfTabToSwitchTo
        guard tabsStackView.arrangedSubviews.indices.contains(index) else { return }

        let selectedTabView = tabsStackView.arrangedSubviews[index]
        let tabFrameInContentView = selectedTabView.convert(selectedTabView.bounds, to: scrollView.contentView)
        let visibleRect = scrollView.contentView.bounds
        
        DispatchQueue.main.async {
            if tabFrameInContentView.minY < visibleRect.minY {
                self.scrollView.contentView.bounds.origin.y = tabFrameInContentView.minY
            }
            
            if tabFrameInContentView.maxY > visibleRect.maxY {
                self.scrollView.contentView.bounds.origin.y = tabFrameInContentView.maxY - visibleRect.height
            }
        }
    }
    
    private func scrollToTop() {
        scrollView.contentView.scrollToVisible(NSRect(x: 0, y: 0, width: scrollView.frame.width, height: 1))
    }
    
    func handleNavigationKeyPresses(event: NSEvent) {
        let isTabsSwitcherNeededToStayOpen = appState.isTabsSwitcherNeededToStayOpen
        
        guard isUserHoldingShortcutModifiers(event: event) || isTabsSwitcherNeededToStayOpen else { return }
        guard !appState.savedTabs.isEmpty else { return }
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
    
    private func setBorderRadius() {
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        
        /// without this corner radius is not set on macOS 13.0. On 15.0 it works without masksToBounds
        view.layer?.masksToBounds = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
