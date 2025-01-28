import Foundation

let extensionBundleIdentifier = "kopyl.tab-finder-9.Extension"

enum NavigationKeys: UInt16 {
    case `return` = 36
    case tab = 48
    case backTick = 50
    case escape = 53
    case arrowDown = 125
    case arrowUp = 126
}

enum TypingKeys: UInt16 {
    case arrowLeft = 123
    case arrowRight = 124
    case backspace = 51
}

let notificationName = Notification.Name("com.tabfinder.example.notification")
