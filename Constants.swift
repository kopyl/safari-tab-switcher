import Foundation

let bundleID = Bundle.main.bundleIdentifier ?? ""
let extensionBundleIdentifier = "\(bundleID).Extension"

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

let appGroup = "9QNMAN8CT6.tabfinder.sharedgroup"

class Copy {
    class Onboarding {    
        static let description = "Switch easily between last open tabs in the same way you switch between last open apps"
        static let title = "Welcome to Tab Finder"
        static let button = "Start using Tab Finder"
    }
}

class AssetNames {
    class Onboarding {
        static let left = "onboardingLeft"
        static let right = "onboardingRight"
    }
}

