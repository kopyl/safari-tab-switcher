import Cocoa

class TabsHeaderView: NSView {
    private let title: String
    public var height: CGFloat
    public var initHeight: CGFloat
    public let topInset: CGFloat
    public let standardHeaderHeight: CGFloat = 66
    
    private let leftInset: CGFloat = 25
    private let countView: NSTextField
    
    private var titleViewCenterYAnchor = NSLayoutConstraint()
    private var countViewCenterYAnchor = NSLayoutConstraint()
    
    public var tabsCount: Int = 0 {
        didSet {
            countView.stringValue = String(tabsCount)
            
            if tabsCount == 0 {
                frame.size.height = 0
                height = 0
                isHidden = true
            }
            else {
                height = initHeight
                frame.size.height = initHeight
                isHidden = false
            }
        }
    }
    
    public func shiftInnerConterY(by shift: CGFloat) {
        titleViewCenterYAnchor.constant = shift
        countViewCenterYAnchor.constant = shift
    }
    
    init(frame frameRect: NSRect, title: String, height: CGFloat?, topInset: CGFloat = 0) {
        self.title = title
        self.height = height ?? standardHeaderHeight
        self.initHeight = height ?? standardHeaderHeight
        self.topInset = topInset
        
        
        countView = NSTextField(labelWithString: String(tabsCount))
        
        super.init(frame: frameRect)
        
        let titleView = NSTextField(labelWithString: title)
        titleView.font = .systemFont(ofSize: 13, weight: .semibold)
        titleView.textColor = .secondaryLabelColor
        titleView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(titleView)
        
        countView.font = .systemFont(ofSize: 13, weight: .regular)
        countView.textColor = .secondaryLabelColor
        countView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(countView)
        
        titleViewCenterYAnchor = titleView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: topInset)
        countViewCenterYAnchor = countView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: topInset)
        
        NSLayoutConstraint.activate([
            titleViewCenterYAnchor,
            countViewCenterYAnchor,
            
            titleView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: leftInset),
            countView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -leftInset)
        ])
    }
    
    convenience init(title: String, height: CGFloat?, topInset: CGFloat = 0) {
        self.init(frame: .zero, title: title, height: height, topInset: topInset)
        
        frame = NSRect(
            x: 0,
            y: 0,
            width: tabsPanelWidth,
            height: height ?? standardHeaderHeight
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class NSViewWithDynamicAppearance: NSView {

    private let updateHandler: (NSView) -> Void

    init(frame: NSRect = .zero, onAppearanceChange: @escaping (NSView) -> Void) {
        self.updateHandler = onAppearanceChange
        super.init(frame: frame)
        wantsLayer = true
        updateHandler(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHandler(self)
    }
}
