import SafariServices
import SwiftUI


@available(macOSApplicationExtension 10.15, *)
class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared = SafariExtensionViewController()

    override func loadView() {
        // Embed SwiftUI view inside the hosting controller
        let swiftUIView = HelloWorldView()
        let hostingController = NSHostingController(rootView: swiftUIView)
        
        // Set the hosted SwiftUI view as the main view
        self.view = hostingController.view
        self.preferredContentSize = NSSize(width: 300, height: 200) // Adjust size as needed
    }
}


//
//  SafariExtensionViewController.swift
//  sss Extension
//
//  Created by Oleh Kopyl on 05.01.2025.
//

//import SafariServices
//
//class SafariExtensionViewController: SFSafariExtensionViewController {
//    
//    static let shared: SafariExtensionViewController = {
//        let shared = SafariExtensionViewController()
//        shared.preferredContentSize = NSSize(width:320, height:240)
//        return shared
//    }()
//
//}
