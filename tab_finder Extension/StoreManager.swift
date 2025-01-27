import Foundation
import SafariServices

struct Tab: Codable {
    var id: Int
    var title: String = ""
    var host: String = ""
    
    init(id: Int, tab: SFSafariTab) async {
        self.id = id
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
    private static let key = "tabIDsWithTitleAndHost"

    static var tabIDsWithTitleAndHost: Tabs {
            get {
                guard let data = userDefaults.data(forKey: key) else { return Tabs() }
                guard let decodedData = decode([Tab].self, from: data) else { return Tabs() }
                return Tabs(decodedData)
            }
            set {
                guard let encodedData = encode(Tabs(newValue.tabs).tabs) else { return }
                userDefaults.set(encodedData, forKey: key)
            }
        }
}
