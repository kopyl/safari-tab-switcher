import Cocoa
import SafariServices
import SwiftUI

@available(macOS 10.15, *)
struct HelloWorldView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
            .padding()
        }
    }
}

@main
@available(macOS 11.0, *)
struct MySafariApp: App {
    var body: some Scene {
        WindowGroup {
            HelloWorldView()
                .onAppear {
                    NSApplication.shared.terminate(nil)
                }
        }
    }
}
