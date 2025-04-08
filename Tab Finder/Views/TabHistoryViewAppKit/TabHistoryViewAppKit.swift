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
        tabsStackView = makeStackView(spacing: 4)
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
        
        /// wiithout thid SwiftUI is not able to respond on `.onTapGesture` events
        flippedView.frame = CGRect(origin: .zero, size: CGSize(width: 792, height: 0))
        flippedView.autoresizingMask = [.width]
        
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
        self.tabsStackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
    
    private func renderTabs() {
        self.tabsStackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for tab in appState.renderedTabs {
            let tabView = AppKitTabItemView(tab: tab)
            self.tabsStackView?.addArrangedSubview(tabView)
            
            NSLayoutConstraint.activate([
                tabView.leadingAnchor.constraint(equalTo: tabsStackView.leadingAnchor, constant: 4),
                tabView.trailingAnchor.constraint(equalTo: tabsStackView.trailingAnchor, constant: -4),
            ])
        }
        
        DispatchQueue.main.async {
            let fittingHeight = self.tabsStackView?.fittingSize.height ?? 0
            self.scrollView.documentView?.frame.size.height = fittingHeight
        }
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
        view.layer?.cornerRadius = 8
        
        /// without this corner radius is not set on macOS 13.0. On 15.0 it works without masksToBounds
        view.layer?.masksToBounds = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

final class AppKitTabItemView: NSView {
    
    private let titleLabel: NSTextField
    private let hostLabel: NSTextField
    
    init(tab: Tab) {
        titleLabel = NSTextField(labelWithString: tab.title)
        hostLabel = NSTextField(labelWithString: tab.host)
        
        super.init(frame: .zero)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7).cgColor
        
        // Configure title label with proper truncation
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        titleLabel.cell?.truncatesLastVisibleLine = true
        
        // Configure host label with proper truncation
        hostLabel.font = .systemFont(ofSize: 11)
        hostLabel.textColor = .secondaryLabelColor
        hostLabel.lineBreakMode = .byTruncatingTail
        hostLabel.usesSingleLineMode = true
        hostLabel.cell?.truncatesLastVisibleLine = true
        
        // Set constraints on the entire view
        self.translatesAutoresizingMaskIntoConstraints = false
        
        // Create stack view with equal columns
        let stackView = NSStackView(views: [titleLabel, hostLabel])
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually // Equal width columns
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set alignment for better text display
        stackView.alignment = .centerY
        
        // Add the stack view to the main view
        addSubview(stackView)
        
        // Set up constraints for the stack view
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }
}
