import Cocoa
import SwiftUI

class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

func makeBackgroundBlurView() -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.blendingMode = .behindWindow
    v.material = .sidebar
    v.state = .active
    v.translatesAutoresizingMaskIntoConstraints = false
    return v
}

func makeScrollView() -> NSScrollView {
    let sv = NSScrollView()
    sv.translatesAutoresizingMaskIntoConstraints = false
    sv.drawsBackground = false
    return sv
}

func makeStackView(spacing: CGFloat = 0) -> NSStackView {
    let sv = NSStackView()
    sv.orientation = .vertical
    sv.alignment = .leading
    sv.spacing = spacing
    sv.translatesAutoresizingMaskIntoConstraints = false
    return sv
}

func makeTextFieldView() -> NSTextField {
    let textField = NSTextField()
    textField.isBezeled = false
    textField.isBordered = false
    textField.backgroundColor = nil
    textField.focusRingType = .none
    textField.font = NSFont.systemFont(ofSize: 20)
    textField.isEditable = true
    textField.isSelectable = true
    textField.delegate = nil
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
}

func makeHeaderView() -> NSView {
    let headerView = NSView()
    headerView.translatesAutoresizingMaskIntoConstraints = false
    return headerView
}

func makeSearchIconView() -> NSImageView {
    let searchIcon = NSImageView()
    let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "search icon")	
    let config = NSImage.SymbolConfiguration(pointSize: 19, weight: .regular)
    searchIcon.image = image?.withSymbolConfiguration(config)
    searchIcon.translatesAutoresizingMaskIntoConstraints = false
    return searchIcon
}

func makeLinkIcon() -> NSImageView {
    let searchIcon = NSImageView()
    let image = NSImage(systemSymbolName: "arrow.up.forward.app.fill", accessibilityDescription: "link icon")
    let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
    searchIcon.image = image?.withSymbolConfiguration(config)
    searchIcon.translatesAutoresizingMaskIntoConstraints = false
    return searchIcon
}

func makePinImage(isFilled: Bool = false) -> NSImage? {
    let symbolName = isFilled ? "pin.fill" : "pin"
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "pin icon")
    let config = NSImage.SymbolConfiguration(pointSize: 19, weight: .regular)
    return image?.withSymbolConfiguration(config)
}

func makePinButtonView(isFilled: Bool = false, action: Selector? = nil) -> NSButton? {
    guard let pinImage = makePinImage(isFilled: isFilled) else { return nil }
    let pinButton = NSButton(title: "", image: pinImage, target: nil, action: action)
    pinButton.translatesAutoresizingMaskIntoConstraints = false
    pinButton.isBordered = false
    return pinButton
}

func makeColorView() -> NSView {
    let colorView = NSView()
    colorView.wantsLayer = true
    colorView.layer?.opacity = 0.15
    colorView.translatesAutoresizingMaskIntoConstraints = false
    return colorView
}

func makeCloseButton() -> NSButton {
    let _image = NSImage(systemSymbolName: "xmark.square.fill", accessibilityDescription: "Close icon")
    let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
    
    guard let image = _image?.withSymbolConfiguration(config) else {
        return NSButton()
    }
    
    let closeButton = NSButton(title: "", image: image, target: nil, action: nil)
    closeButton.isBordered = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    return closeButton
}

func makeSwipeActionView(target: Any, action: Selector) -> NSView {
    let buttonContainerView = NSView()
    buttonContainerView.wantsLayer = true
    buttonContainerView.layer?.backgroundColor = NSColor.customRed.cgColorAppearanceFix
    buttonContainerView.layer?.cornerRadius = SwipeActionConfig.cornerRadius
    buttonContainerView.translatesAutoresizingMaskIntoConstraints = false
    
    let button = NSButton(title: "", target: target, action: action)
    button.wantsLayer = true
    button.layer?.cornerRadius = SwipeActionConfig.cornerRadius
    button.translatesAutoresizingMaskIntoConstraints = false
    button.isBordered = false
    
    button.layer?.opacity = 1
    
    buttonContainerView.addSubview(button)
    
    NSLayoutConstraint.activate([
        button.leadingAnchor.constraint(equalTo: buttonContainerView.leadingAnchor),
        button.trailingAnchor.constraint(equalTo: buttonContainerView.trailingAnchor),
        button.topAnchor.constraint(equalTo: buttonContainerView.topAnchor),
        button.bottomAnchor.constraint(equalTo: buttonContainerView.bottomAnchor)
    ])
    
    return buttonContainerView
}

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

func makeHeaderLabelView(tabInsets: NSEdgeInsets, tabsHeaderHeight: CGFloat) -> NSTextField {
    let headerLabel = NSTextField(labelWithString: "Open")
    headerLabel.font = .boldSystemFont(ofSize: 13)
    headerLabel.textColor = .secondaryLabelColor
    headerLabel.frame = NSRect(
        x: tabInsets.left,
        y: 0,
        width: tabContentViewWidth,
        height: tabsHeaderHeight
    )
    return headerLabel
}

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
