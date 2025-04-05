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
        
        let visualEffectView = makeVisualEffectView()
        let scrollView = makeScrollView()
        let stackView = makeStackView()

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

        bindTabs(to: stackView, in: scrollView)
    }
    
    private func bindTabs(to stackView: NSStackView, in scrollView: NSScrollView) {
        appState.$renderedTabs
            .receive(on: RunLoop.main)
            .sink { [weak stackView] tabs in
                stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }

                for tab in tabs {
                    let label = NSTextField(labelWithString: tab.host)
                    stackView?.addArrangedSubview(label)
                }

                let fittingHeight = stackView?.fittingSize.height ?? 0
                scrollView.documentView?.frame.size.height = fittingHeight
            }
            .store(in: &cancellables)
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
