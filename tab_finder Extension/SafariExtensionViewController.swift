import SafariServices
import SwiftUI
import os.log

class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()

    override func loadView() {
        let swiftUIView = TooltipView()
        self.view = NSHostingView(rootView: swiftUIView)
    }}
