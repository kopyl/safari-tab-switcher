import SafariServices
import SwiftUI
import os.log

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()

    override func loadView() {
        let swiftUIView = TooltipView()
        let hostingController = NSHostingController(rootView: swiftUIView)

        self.view = hostingController.view
        self.preferredContentSize = NSSize(width: 300, height: 800) // Adjust size as needed
    }}
