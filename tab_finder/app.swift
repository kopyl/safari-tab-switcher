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
            if event.keyCode == 0x00 {
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
