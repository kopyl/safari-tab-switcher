#if DEBUG

import Foundation
import os.log

final class Logger {
    static let shared = Logger()
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let notificationName = NSNotification.Name("com.tabfinder.safariLoggingNotification")
    
    public func setupLoggingFromSafariExtension() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(log),
            name: notificationName,
            object: nil
        )
    }
    
    @objc func log(_ notification: Notification) {
        guard let messageText = notification.object as? String else { return }
        log(messageText)
    }
    
    public func log(_ message: Any...) {
        let messageText = message.map { String(describing: $0) }.joined(separator: " ")
        
        if !bundleID.hasSuffix(".Extension") {
            os_log("%{public}@", "\(messageText)")
            return
        }
        
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: String(messageText),
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

let log = Logger.shared.log as (Any...) -> Void
let setupLoggingFromSafariExtension = Logger.shared.setupLoggingFromSafariExtension

#else

let log = { (_: Any...) in }

#endif
