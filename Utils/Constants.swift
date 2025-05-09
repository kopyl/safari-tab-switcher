import Foundation
import SwiftUI

let visitedPagesHistoryModelName = "VisitedPagesHistoryModel"

class Notifications {
    static let tabClosed = NSNotification.Name("com.tabfinder.tabRemovalNotification")
}

let bundleID = Bundle.main.bundleIdentifier ?? ""
let appName = (Bundle.main.bundleIdentifier ?? "").hasSuffix(".lite") ? "Tab Finder Lite" : "Tab Finder"
let extensionBundleIdentifier = "\(bundleID).Extension"
let tabsPanelID = NSUserInterfaceItemIdentifier("tabsPanel")

let tabsPanelWidth: CGFloat = 800
let tabsPanelHeight: CGFloat = 500

let adButtonHeight: CGFloat = 43

enum NavigationKeys: UInt16 {
    case `return` = 36
    case tab = 48
    case backTick = 50
    case escape = 53
    case arrowDown = 125
    case arrowUp = 126
}

enum AppShortcutKeys: UInt16 {
    case a = 0
    case z = 6
    case x = 7
    case c = 8
    case v = 9
    
    case w = 13
    case p = 35
    case h = 4
    case o = 31
}

enum TypingKeys: UInt16 {
    case arrowLeft = 123
    case arrowRight = 124
    case backspace = 51
}

let appGroup = "9QNMAN8CT6.tabfinder.sharedgroup"
let appStoreURL = "https://apps.apple.com/ua/app/tab-finder-switcher-for-safari/id6741719894"

class Copy {
    class Onboarding {    
        static let description = "Switch easily between last open tabs in the same way you switch between last open apps"
        static let title = "Welcome to \(appName)"
        static let hideThisWindowButton = "Hide \(appName) in Background"
        static let configureShortcutButton = "Change shortcut"
        static let buttonHint = "This app must be running for the extension to work. To reopen the app, click on the extension icon in Safari"
    }
    class Tooltips {
        static let inputSource = "Click to change the language of your input to a previous one. You can also change it by pressing \"space\" key when you haven't enetered your search query yet"
    }
    class TabsPanel {
        static let closeButtonTitle = "Close"
    }
    class Ads {
        static let adButtonTitle = "Buy full version in App Store to see unlimited tabs and get rid of this message"
    }
}

class AssetNames {
    class Onboarding {
        static let left = "onboardingLeft"
        static let right = "onboardingRight"
    }
}
