import Foundation

struct TabInfo: Codable {
    var title: String = "No title"
    var host: String = ""
}

typealias TabsStorage = [String: TabInfo]

struct Store {
    private static let userDefaults = UserDefaults(suiteName: "com.tabfinder.sharedgroup") ?? UserDefaults.standard

    static var tabsTitleAndHost: TabsStorage {
            get {
                guard let data = userDefaults.data(forKey: "tabsTitleAndHost") else {
                    return [:]
                }

                let decoder = JSONDecoder()
                return (try? decoder.decode(TabsStorage.self, from: data)) ?? [:]
            }
            set {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(newValue) {
                    userDefaults.set(data, forKey: "tabsTitleAndHost")
                }
            }
        }

    static var tabIDs: [Int] {
        get {
            return OrderedSet(userDefaults.array(forKey: "tabIDs") as? [Int] ?? []).elements
        }
        set {
            userDefaults.set(OrderedSet(newValue).elements, forKey: "tabIDs")
        }
    }
        }
}
