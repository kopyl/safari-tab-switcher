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

class AutoCompleteTextFieldController: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
    let suggestions = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]
    private let textField: NSTextField
    
    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField,
              let currentText = textField.stringValue.isEmpty ? nil : textField.stringValue else {
            return
        }
        
        let filteredCompletions = suggestions.filter { $0.lowercased().hasPrefix(currentText.lowercased()) }
            
        guard !filteredCompletions.isEmpty else { return }
        guard let fieldEditor = textField.currentEditor() as? NSTextView else { return }
//        fieldEditor.insertCompletion(filteredCompletions[0], forPartialWordRange: fieldEditor.rangeForUserCompletion, movement: 0, isFinal: false)
        
    }

    func control(_ control: NSControl, textView: NSTextView,
                 completions words: [String], forPartialWordRange charRange: NSRange,
                 indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        let partial = (textView.string as NSString).substring(with: charRange).lowercased()
        return suggestions.filter { $0.lowercased().hasPrefix(partial) }
    }
    
    init(textField: NSTextField) {
        self.textField = textField
        super.init()
        self.textField.delegate = self
    }
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

func makeSwipeActionView(target: Any, action: Selector) -> NSViewWithDynamicAppearance {
    let buttonContainerView = NSViewWithDynamicAppearance() { view in
        view.layer?.backgroundColor = NSColor.customRed.cgColorAppearanceFix
    }
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
