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

func makePinIcon() -> NSImageView {
    let pinIcon = NSImageView()
    let image = NSImage(systemSymbolName: "pin", accessibilityDescription: "pin icon")	
    let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
    pinIcon.image = image?.withSymbolConfiguration(config)
    pinIcon.translatesAutoresizingMaskIntoConstraints = false
    return pinIcon
}