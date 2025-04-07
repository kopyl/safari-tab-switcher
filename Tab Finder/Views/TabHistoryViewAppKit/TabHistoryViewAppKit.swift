import SwiftUI

class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

class AppKitTabHistoryView: NSViewController {
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let visualEffectView = makeVisualEffectView()
        scrollView = makeScrollView()
        stackView = makeStackView()

        view.addSubview(visualEffectView)
        view.addSubview(scrollView)

        let flippedView = FlippedView()
        flippedView.translatesAutoresizingMaskIntoConstraints = false
        flippedView.addSubview(stackView)

        scrollView.documentView = flippedView

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        setBorderRadius()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(self.view)
        scrollToTop()
    }
    
    override func viewWillAppear() {
        stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for tab in appState.renderedTabs {
            let tabView = NSHostingView(rootView: TabItemView(tab: tab))
            stackView?.addArrangedSubview(tabView)
            
            NSLayoutConstraint.activate([
                tabView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 4),
                tabView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -4),
            ])
        }

        let fittingHeight = stackView?.fittingSize.height ?? 0
        scrollView.documentView?.frame.size.height = fittingHeight
    }
    
    override func keyDown(with event: NSEvent) {
        handleNavigationKeyPresses(event: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        handleKeyRelease(event: event)
    }
    
    private func scrollToSelectedTabWithoutAnimation() {
        /// https://kopyl.gitbook.io/tab-finder/appkit-rewrite/features/scrolling/current-implementation-specifics
        
        guard let scrollView = view.subviews.compactMap({ $0 as? NSScrollView }).first,
              let stackView = scrollView.documentView?.subviews.first(where: { $0 is NSStackView }) as? NSStackView else {
            return
        }

        let index = appState.indexOfTabToSwitchTo
        guard stackView.arrangedSubviews.indices.contains(index) else { return }

        let selectedTabView = stackView.arrangedSubviews[index]
        let tabFrameInContentView = selectedTabView.convert(selectedTabView.bounds, to: scrollView.contentView)
        let visibleRect = scrollView.contentView.bounds
        
        DispatchQueue.main.async {
            if tabFrameInContentView.minY < visibleRect.minY {
                scrollView.contentView.bounds.origin.y = tabFrameInContentView.minY
            }
            
            if tabFrameInContentView.maxY > visibleRect.maxY {
                scrollView.contentView.bounds.origin.y = tabFrameInContentView.maxY - visibleRect.height
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
}
