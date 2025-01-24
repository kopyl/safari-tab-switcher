import Foundation
import SafariServices

struct TabInfoWithID: Codable, Hashable, Identifiable {
    var id: Int
    var title: String = ""
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

    static var tabIDsWithTitleAndHost: Tabs {
            get {
                guard let data = userDefaults.data(forKey: "tabIDsWithTitleAndHost") else { return Tabs() }
                guard let decodedData = decode([TabInfoWithID].self, from: data) else { return Tabs() }
                return Tabs(decodedData)
            }
            set {
                guard let encodedData = encode(Tabs(newValue.tabs).tabs) else { return }
                userDefaults.set(encodedData, forKey: "tabIDsWithTitleAndHost")
            }
        }
}
