import XCTest

final class SwipingALotShouldNotCauseMemoryLeakTest: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        
        let safariApp = XCUIApplication(bundleIdentifier: "com.apple.Safari")
        safariApp.launch()
    }

    func testFaviconMemoryCycle() throws {
        pressOptionTab()
        scrollToBottom()
    }
    
    func pressOptionTab() {
        let optionFlag: CGEventFlags = .maskAlternate
        let tabKey: CGKeyCode = 48
        
        globalKeyDown(tabKey, flags: optionFlag)
        globalKeyUp(tabKey, flags: optionFlag)
    }
    
    func globalKeyDown(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
    }

    func globalKeyUp(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
    
    func swipeScroll(yDelta: Int32, times: Int, delay: useconds_t = 0) {
        for _ in 0..<times {
            let event = CGEvent(scrollWheelEvent2Source: nil,
                                units: .pixel,
                                wheelCount: 1,
                                wheel1: yDelta,
                                wheel2: 0,
                                wheel3: 0)
            event?.post(tap: .cghidEventTap)
            usleep(delay)
        }
    }
    
    private func scrollToBottom() {
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            while true {
                swipeScroll(yDelta: -100, times: 100)
                usleep(100)
                scrollView.swipeUp()
            }
        }
    }
}
