import Foundation

struct TabInfo: Codable {
    var title: String = "No title"
    var host: String = ""
}

typealias TabsStorage = [String: TabInfo]

struct Store {
    private static let userDefaults = UserDefaults(suiteName: "com.tabfinder.sharedgroup") ?? UserDefaults.standard

    static var allOpenTabsUniqueWithTitlesAndHosts: TabsStorage {
            get {
                guard let data = userDefaults.data(forKey: "allOpenTabsUniqueWithTitlesAndHosts") else {
                    return [:] // Return an empty dictionary if no data exists
                }
                
                // Decode the data into `TabsStorage`
                let decoder = JSONDecoder()
                return (try? decoder.decode(TabsStorage.self, from: data)) ?? [:]
            }
            set {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(newValue) {
                    userDefaults.set(data, forKey: "allOpenTabsUniqueWithTitlesAndHosts")
                }
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
