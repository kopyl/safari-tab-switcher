import SwiftUI
import Combine

class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

class AppKitTabHistoryView: NSViewController {
    private var cancellables: Set<AnyCancellable> = []
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .sidebar
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)
        
        let scrollView = NSScrollView(frame: view.bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let flippedView = FlippedView(frame: scrollView.bounds)
        flippedView.addSubview(stackView)
        scrollView.documentView = flippedView
        
        appState.$renderedTabs
            .sink { [weak stackView] tabs in
                stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
                
                for tab in tabs {
                    let textView = NSTextField(labelWithString: tab.host)
                    stackView?.addArrangedSubview(textView)
                }
                
                let height = stackView?.fittingSize.height ?? 0
                scrollView.documentView?.frame.size = CGSize(width: scrollView.contentSize.width, height: height)
            }
            .store(in: &cancellables)
        
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
