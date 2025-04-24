import XCTest

final class SwipingWithForceToTheBottomShouldNotCrashAppTest: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        
        openSafari()
    }
    
    func openSafari() {
        let safariApp = XCUIApplication(bundleIdentifier: "com.apple.Safari")
        safariApp.launch()
    }

    func testFaviconMemoryCycle() throws {
        while true {
            pressOptionTab()
            usleep(100)
            scrollToBottom()
            pressEscape()
        }
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

    private func pressEscape() {
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
    }
    
    func swipeScroll(yDelta: Int32) {
        let event = CGEvent(scrollWheelEvent2Source: nil,
                            units: .pixel,
                            wheelCount: 1,
                            wheel1: yDelta,
                            wheel2: 0,
                            wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }
    
    private func scrollToBottom() {
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<6 {
            scrollView.swipeUp(velocity: .init(integerLiteral: 10000))
        }
    }
}
