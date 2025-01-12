import SwiftUI

struct HelloWorldView: View {
    var body: some View {
        EmptyView()
        .onAppear {
            setupKeyListener()
        }
    }
    
    private func bringWindowToFront() {
        if let window = NSApplication.shared.windows.first {
            window.orderFrontRegardless()
        }
    }
    
    func setupKeyListener() {
            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                log("\(event.modifierFlags.rawValue)")
                if event.keyCode == 48 && event.modifierFlags.rawValue == 1573160 {
                    bringWindowToFront()
                }
            }
        }
}

@main
struct MySafariApp: App {
    var body: some Scene {
        WindowGroup {
            HelloWorldView()
        }
    }
}
