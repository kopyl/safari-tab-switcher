import Cocoa

class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

func makeVisualEffectView() -> NSVisualEffectView {
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

func makeTextField() -> NSTextField {
    let textField = NSTextField()
    textField.isBezeled = false
    textField.isBordered = false
    textField.backgroundColor = nil
    textField.focusRingType = .none
    textField.font = NSFont.systemFont(ofSize: 26)
    textField.isEditable = true
    textField.isSelectable = true
    textField.delegate = nil
    textField.placeholderAttributedString = NSAttributedString(string: "Placeholder", attributes: [
        .foregroundColor: NSColor.white.withAlphaComponent(0.3),
        .font: NSFont.systemFont(ofSize: 26)
    ])
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
}

func makeHeaderView() -> NSView {
    let headerView = NSView()
    headerView.translatesAutoresizingMaskIntoConstraints = false
    return headerView
}

func makeSearchIcon() -> NSImageView {
    let searchIcon = NSImageView()
    let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "search icon")	
    let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
    searchIcon.image = image?.withSymbolConfiguration(config)
    searchIcon.translatesAutoresizingMaskIntoConstraints = false
    return searchIcon
}

func makePinImage(isFilled: Bool = false) -> NSImage? {
    let symbolName = isFilled ? "pin.fill" : "pin"
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "pin icon")
    let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
    return image?.withSymbolConfiguration(config)
}

func makePinButton(isFilled: Bool = false, action: Selector? = nil) -> NSButton? {
    guard let pinImage = makePinImage(isFilled: isFilled) else { return nil }
    let pinButton = NSButton(title: "", image: pinImage, target: nil, action: action)
    pinButton.translatesAutoresizingMaskIntoConstraints = false
    pinButton.isBordered = false
    return pinButton
}

func makeColorView(hex: String? = "#fffff") -> NSView {
    let colorView = NSView()
    colorView.wantsLayer = true
    colorView.layer?.backgroundColor = hexToColor(hex ?? "#fffff").cgColor
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
