import Foundation
import SafariServices

func encode<T: Codable>(_ value: T) -> Data? {
    let encoder = JSONEncoder()
    return try? encoder.encode(value)
}

func decode<T: Codable>(_ type: T.Type, from data: Data) -> T? {
    let decoder = JSONDecoder()
    return try? decoder.decode(T.self, from: data)
}

struct TabInfo: Codable {
    var title: String = "No title"
    var host: String = ""
}

struct TabInfoWithID: Codable, Hashable {
    var id: Int
    var title: String = "No title"
    var host: String = ""
    
    init(tabId: Int, tab: SFSafariTab) async {
        self.id = tabId
        await setTitleAndHostFromTab(tab: tab)
    }
    
    mutating func setTitleAndHostFromTab(tab: SFSafariTab) async {
            if let activePage = await tab.activePage() {
                if let properties = await activePage.properties() {
                    title = properties.title ?? "No title"
                    host = properties.url?.host ?? ""
                }
            }
        }
}

typealias TabsStorage = [String: TabInfo]
typealias TabsStorageWithTabID = [String: TabInfoWithID]

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
    
    static var tabIDsWithTitleAndHost: [TabInfoWithID] {
        get {
            if let data = userDefaults.data(forKey: "tabIDsWithTitleAndHost") {
                return OrderedSet(decode([TabInfoWithID].self, from: data) ?? []).elements
            }
            return []
        }
        set {
            if let encodedData = encode(OrderedSet(newValue).elements) {
                userDefaults.set(encodedData, forKey: "tabIDsWithTitleAndHost")
            }
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
