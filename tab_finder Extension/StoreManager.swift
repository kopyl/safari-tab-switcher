import Foundation

struct Store {
    private static let userDefaults = UserDefaults(suiteName: "com.tabfinder.sharedgroup") ?? UserDefaults.standard

    static var allOpenTabsUniqueWithTitles: [String: String] {
        get {
            return userDefaults.dictionary(forKey: "allOpenTabsUniqueWithTitles") as? [String: String] ?? [:]
        }
        set {
            userDefaults.set(newValue, forKey: "allOpenTabsUniqueWithTitles")
        }
    }
    
    static var allOpenTabsUnique: [Int] {
        get {
            return OrderedSet(userDefaults.array(forKey: "allOpenTabsUnique") as? [Int] ?? []).elements
        }
        set {
            userDefaults.set(newValue, forKey: "allOpenTabsUnique")
        }
    }
    
    static var currentTabId: Int {
        get {
            return userDefaults.object(forKey: "currentTabId") as? Int ?? -1
        }
        set {
            userDefaults.set(newValue, forKey: "currentTabId")
        }
    }
}
