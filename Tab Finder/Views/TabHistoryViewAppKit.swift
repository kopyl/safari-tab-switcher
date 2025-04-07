import SwiftUI
import Combine

class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

class AppKitTabHistoryView: NSViewController {
    private var cancellables: Set<AnyCancellable> = []
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }
    
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
                tabView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                tabView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
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
    
    private func scrollToSelectedTab() {
        guard let scrollView = view.subviews.compactMap({ $0 as? NSScrollView }).first,
              let stackView = scrollView.documentView?.subviews.first(where: { $0 is NSStackView }) as? NSStackView else {
            return
        }

        let index = appState.indexOfTabToSwitchTo
        guard stackView.arrangedSubviews.indices.contains(index) else { return }

        let selectedTabView = stackView.arrangedSubviews[index]
        let tabFrameInContentView = selectedTabView.convert(selectedTabView.bounds, to: scrollView.contentView)

        DispatchQueue.main.async {
            scrollView.contentView.scrollToVisible(tabFrameInContentView)
        }
    }
    
    private func scrollToTop() {
        guard let scrollView = view.subviews.compactMap({ $0 as? NSScrollView }).first else { return }
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
            scrollToSelectedTab()
        case .tab:		
            if event.modifierFlags.contains(.shift) {
                appState.indexOfTabToSwitchTo -= 1
            } else {
                appState.indexOfTabToSwitchTo += 1
            }
            scrollToSelectedTab()
        case .arrowDown:
            appState.indexOfTabToSwitchTo += 1
            scrollToSelectedTab()
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
    
    private func makeVisualEffectView() -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.material = .sidebar
        v.state = .active
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeScrollView() -> NSScrollView {
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.drawsBackground = false
        return sv
    }

    private func makeStackView() -> NSStackView {
        let sv = NSStackView()
        sv.orientation = .vertical
        sv.alignment = .leading
        sv.spacing = 10
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }
}
