import SafariServices
import os.log
import SwiftUI

@available(macOSApplicationExtension 10.15, *)
struct HelloWorldView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
                .font(.largeTitle)
                .padding()
            Button("Close") {
                // Add functionality to close the popover if needed
            }
            .padding()
        }
    }
}


@available(macOSApplicationExtension 10.15, *)
class SafariExtensionHandler: SFSafariExtensionHandler {

    override func toolbarItemClicked(in window: SFSafariWindow) {
        os_log(.default, "Toolbar item clicked")
        // Safari will automatically show the popover via the popoverViewController() method
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping (Bool, String) -> Void) {
        validationHandler(true, "") // Enable toolbar item
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        // Return the shared instance of the popover
        return SafariExtensionViewController.shared
    }
}
