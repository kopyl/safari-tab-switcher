import SafariServices
import SwiftUI
import os.log

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()

    override func loadView() {
        let swiftUIView = HelloWorldView()
        let hostingController = NSHostingController(rootView: swiftUIView)

        self.view = hostingController.view
        self.preferredContentSize = NSSize(width: 300, height: 200) // Adjust size as needed
    }}
