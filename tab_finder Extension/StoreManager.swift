import Foundation
import SafariServices

struct TabInfo: Codable {
    var title: String = "No title"
    var host: String = ""
}

struct TabInfoWithID: Codable, Hashable, Identifiable {
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

func encode<T: Codable>(_ value: T) -> Data? {
    let encoder = JSONEncoder()
    return try? encoder.encode(value)
}

func decode<T: Codable>(_ type: T.Type, from data: Data) -> T? {
    let decoder = JSONDecoder()
    return try? decoder.decode(T.self, from: data)
}

struct Store {
    private static let userDefaults = UserDefaults(suiteName: "com.tabfinder.sharedgroup") ?? UserDefaults.standard

    static var tabIDsWithTitleAndHost: OrderedSet2<TabInfoWithID> {
            get {
                if let data = userDefaults.data(forKey: "tabIDsWithTitleAndHost") {
                    return OrderedSet2(decode([TabInfoWithID].self, from: data) ?? [])
                }
                return OrderedSet2([])
            }
            set {
                if let encodedData = encode(OrderedSet2(newValue.elements).elements) {
                    userDefaults.set(encodedData, forKey: "tabIDsWithTitleAndHost")
                }
            }
        }
}
