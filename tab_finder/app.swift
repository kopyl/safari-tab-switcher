import SwiftUI

struct HelloWorldView: View {
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack {
            Text("Hello, World!")
            .padding()
        }
        .onAppear {
            setupKeyListener()
        }
        .onDisappear {
            removeKeyListener()
        }
    }
    
    private func bringWindowToFront() {
        if let window = NSApplication.shared.windows.first {
            window.orderFrontRegardless()
        }
    }
    
    func setupKeyListener() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 0x00 {
                bringWindowToFront()
            }
        }
    }
    
    func removeKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
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
