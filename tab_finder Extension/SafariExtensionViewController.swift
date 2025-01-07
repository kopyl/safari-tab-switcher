import SafariServices
import SwiftUI
import os.log

@available(macOSApplicationExtension 12.0, *)
class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()

    override func loadView() {
        // Embed SwiftUI view inside the hosting controller
        let swiftUIView = HelloWorldView()
        let hostingController = NSHostingController(rootView: swiftUIView)
        
        // Set the hosted SwiftUI view as the main view
        self.view = hostingController.view
        self.preferredContentSize = NSSize(width: 300, height: 200) // Adjust size as needed
    }}
