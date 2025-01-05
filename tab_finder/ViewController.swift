import Cocoa
import SafariServices
import SwiftUI
import WebKit

let extensionBundleIdentifier = "kopyl.tab-finder.Extension"

@available(macOS 10.15, *)
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update the view if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {}
}

@available(macOS 10.15, *)
struct HelloWorldView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
                .font(.largeTitle)
                .padding()

            Button("Open Preferences") {
                SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .padding()

            WebView(url: Bundle.main.url(forResource: "Main", withExtension: "html")!)
                .frame(height: 300)
        }
        .padding()
    }
}
