import Foundation
import SwiftUI

let bundleID = Bundle.main.bundleIdentifier ?? ""
let extensionBundleIdentifier = "\(bundleID).Extension"
let tabsPanelID = NSUserInterfaceItemIdentifier("tabsPanel")

let tabsPanelWidth: CGFloat = 800
let tabsPanelHeight: CGFloat = 500

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

let appGroup = "9QNMAN8CT6.tabfinder.sharedgroup"

class Copy {
    class Onboarding {    
        static let description = "Switch easily between last open tabs in the same way you switch between last open apps"
        static let title = "Welcome to Tab Finder"
        static let hideThisWindowButton = "Hide Tab Finder in Background"
        static let configureShortcutButton = "Change shortcut"
        static let buttonHint = "This app must be running for the extension to work. To reopen the app, click on the extension icon in Safari"
    }
    class Tooltips {
        static let inputSource = "Click to change the language of your input to a previous one. You can also change it by pressing \"space\" key when you haven't enetered your search query yet"
    }
    class TabsPanel {
        static let closeButtonTitle = "Close"
    }
}

class AssetNames {
    class Onboarding {
        static let left = "onboardingLeft"
        static let right = "onboardingRight"
    }
}
