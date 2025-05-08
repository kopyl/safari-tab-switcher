import Cocoa

class AdButtonView: NSView {
    private let backgroundColor = NSColor.nearInvisible
    private let linkIcon: NSView
    private let button: NSButton
    
    override init(frame frameRect: NSRect) {
        button = NSButton(title: "", target: nil, action: #selector(Application.openAppStoreLink))
        button.isBordered = false
        button.alignment = .left
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 15
        
        let attributedTitle = NSAttributedString(
            string: Copy.Ads.adButtonTitle,
            attributes: [
                .paragraphStyle: paragraphStyle
            ]
        )
        button.attributedTitle = attributedTitle
        button.translatesAutoresizingMaskIntoConstraints = false
        
        linkIcon = makeLinkIcon()
        
        super.init(frame: frameRect)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = SwipeActionConfig.cornerRadius
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.layer?.backgroundColor = backgroundColor.cgColorAppearanceFix
        
        addSubview(button)
        addSubview(linkIcon)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            linkIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            linkIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.layer?.backgroundColor = backgroundColor.cgColorAppearanceFix
    }
}
