import SafariServices
import SwiftUI

struct HelloWorldView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
            .padding()
        }
    }
}

@main
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
