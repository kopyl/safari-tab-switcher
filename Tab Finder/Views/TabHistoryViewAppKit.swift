import SwiftUI
import Combine

class AppKitTabHistoryView: NSViewController {
    private var cancellables: Set<AnyCancellable> = []
    
    private var scrollView: NSScrollView!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView = NSScrollView(frame: view.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = stackView
        
        appState.$renderedTabs
            .sink { [weak stackView] newTabs in
                stackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }
                
                for item in newTabs {
                    let textView = NSTextField(labelWithString: item.host)
                    stackView?.addArrangedSubview(textView)
                }
            }
            .store(in: &cancellables)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 10)
        ])
        
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
