import Cocoa
import SwiftUI

class WindowConfig {
    static let width: CGFloat = 659
    static let height: CGFloat = 400
    
    #if LITE
    /// To fit the name of the app "Tab Finder Lite"
    static let sidebarFixedWidth: CGFloat = 250
    #else
    static let sidebarFixedWidth: CGFloat = 215
    #endif
    
    static let sideBarTopPadding: CGFloat = 63
}

class NoPaddingCellView: NSTableCellView {
    override func layout() {
        super.layout()
        if let subview = subviews.first {
            subview.frame.origin.x = -2
        }
    }
}

enum SidebarItem: String, CaseIterable {
    case shortcut = "Shortcut"
    case appearance = "Appearance"
    case general = "General"
    
    var icon: NSImageView {
        let imageName = "\(self.rawValue)-icon"
        
        guard let image = NSImage(named: NSImage.Name(imageName)) else {
            fatalError("Missing image: \(imageName)")
        }
        
        let imageView = NSImageView(image: image)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return imageView
    }
    
    var viewController: NSViewController {
        switch self {
        case .shortcut:
            return NSHostingController(rootView: ShortcutSettingsView(appState: appState))
        case .appearance:
            return NSHostingController(rootView: AppearanceSettingsView(appState: appState))
        case .general:
            return NSHostingController(rootView: GeneralSettingsView(appState: appState))
        }
    }
}

protocol SidebarSelectionDelegate: AnyObject {
    func didSelectSidebarItem(_ item: SidebarItem)
}

class DraggableView: NSView {
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

class SettingsTitleView: NSTextField {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    init() {
        super.init(frame: .zero)
        stringValue = "Settings"
        isBezeled = false
        drawsBackground = false
        isEditable = false
        isBordered = false
        isSelectable = false
        font = .systemFont(ofSize: 20)
        translatesAutoresizingMaskIntoConstraints = false
        
        Task {
            textColor = .settingsText
        }
    }
}

class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    weak var delegate: SidebarSelectionDelegate?
    
    private let items = SidebarItem.allCases

    override func loadView() {
        self.view = NSView()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column"))
        settingsSidebarTableView.addTableColumn(column)
        settingsSidebarTableView.delegate = self
        settingsSidebarTableView.dataSource = self
        settingsSidebarTableView.rowHeight = 32
        settingsSidebarTableView.translatesAutoresizingMaskIntoConstraints = false
        settingsSidebarTableView.focusRingType = .none
        
        DispatchQueue.main.async {
            settingsSidebarTableView.selectRowIndexes([0], byExtendingSelection: false)
        }
        
        view.addSubview(settingsWindowTitle)
        view.addSubview(settingsSidebarTableView)
        
        let draggableView = DraggableView()
        draggableView.translatesAutoresizingMaskIntoConstraints = false
        draggableView.wantsLayer = true
        view.addSubview(draggableView)
        NSLayoutConstraint.activate([
            draggableView.heightAnchor.constraint(equalToConstant: WindowConfig.sideBarTopPadding + 10),
            draggableView.widthAnchor.constraint(equalToConstant: WindowConfig.sidebarFixedWidth),
            draggableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            
            settingsWindowTitle.topAnchor.constraint(equalTo: view.topAnchor, constant: WindowConfig.sideBarTopPadding),
            settingsWindowTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
        
        NSLayoutConstraint.activate([
            settingsSidebarTableView.topAnchor.constraint(equalTo: settingsWindowTitle.bottomAnchor, constant: 25),
        ])
        
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let textLabel = NSTextField(labelWithString: items[row].rawValue)
        let imageView = items[row].icon
        
        let stackView = NSStackView(views: [imageView, textLabel])
        stackView.spacing = 4
        stackView.heightAnchor.constraint(equalToConstant: tableView.rowHeight).isActive = true
        
        let cell = NoPaddingCellView()
        cell.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: cell.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
        ])
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedIndex = settingsSidebarTableView.selectedRow
        guard selectedIndex >= 0 else { return }
        delegate?.didSelectSidebarItem(items[selectedIndex])
    }
}

class SplitViewController: NSSplitViewController, SidebarSelectionDelegate {
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: WindowConfig.width, height: WindowConfig.height))
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarVC = SidebarViewController()
        sidebarVC.delegate = self

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = WindowConfig.sidebarFixedWidth
        sidebarItem.maximumThickness = WindowConfig.sidebarFixedWidth
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)
        
        let detailItem = NSSplitViewItem(viewController: SidebarItem.shortcut.viewController)
        addSplitViewItem(detailItem)
    }

    func didSelectSidebarItem(_ item: SidebarItem) {
        removeSplitViewItem(splitViewItems[1])
        let newDetailItem = NSSplitViewItem(viewController: item.viewController)
        addSplitViewItem(newDetailItem)
    }
}

func addPaddingToWindowButtons(leading: CGFloat, top: CGFloat) {
    if settingsWindow?.standardWindowButton(.miniaturizeButton)?.frame.origin.y != 34 {
        return
    }
    
    settingsWindow?.standardWindowButton(.miniaturizeButton)?.frame.origin.y -= top
    settingsWindow?.standardWindowButton(.closeButton)?.frame.origin.y -= top
    settingsWindow?.standardWindowButton(.zoomButton)?.frame.origin.y -= top
    
    settingsWindow?.standardWindowButton(.miniaturizeButton)?.frame.origin.x += leading
    settingsWindow?.standardWindowButton(.closeButton)?.frame.origin.x += leading
    settingsWindow?.standardWindowButton(.zoomButton)?.frame.origin.x += leading
    
    let buttonContainer = settingsWindow?.standardWindowButton(.closeButton)?.superview
    
    for subview in buttonContainer?.subviews ?? [] where subview is NSTextField {
        subview.frame.origin.y -= top
    }
}


class SettingsWindowController: NSWindowController {
    override init(window: NSWindow?) {
        super.init(window: window)
        
        NotificationCenter.default.addObserver(
                self,
           selector: #selector(windowDidResize(_:)),
           name: NSWindow.didResizeNotification,
           object: settingsWindow
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func windowDidResize(_ notification: Notification) {
        addPaddingToWindowButtons(leading: 10, top: 10)
    }
    
    deinit {
            NotificationCenter.default.removeObserver(
                self,
            name: NSWindow.didResizeNotification,
            object: self.window
        )
    }
}

#Preview {
    GeneralSettingsView(appState: appState)
}
