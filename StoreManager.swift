import Foundation
import SafariServices

struct _Window: Codable {
    var tabs: Tabs
    var combinedID: String
    
    init(tabs: Tabs) {
        self.tabs = tabs
        self.combinedID = "-" + tabs.sorted{$0.id > $1.id}.map{$0.title}.joined()
    }
    
    enum CodingKeys: String, CodingKey {
            case tabs
            case combinedID
        }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tabs = try container.decode(Tabs.self, forKey: .tabs)
        self.combinedID = try container.decode(String.self, forKey: .combinedID)
    }
}

struct Tab: Codable {
    var id: Int
    var title: String = ""
    var host: String = ""
    
    init(id: Int, tab: SFSafariTab) async {
        self.id = id
        await setTitleAndHostFromTab(tab: tab)
    }
    
    init(tab: SFSafariTab) async {
        self.id = -1
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
    private static let userDefaults = UserDefaults(suiteName: "9QNMAN8CT6.tabfinder.sharedgroup") ?? UserDefaults.standard
    private static let windowsStoreKey = "windows"

    static var windows: Windows {
            get {
                guard let data = userDefaults.data(forKey: windowsStoreKey) else { return Windows() }
                guard let decodedData = decode([_Window].self, from: data) else { return Windows() }
                return Windows(decodedData)
            }
            set {
                guard let encodedData = encode(newValue.windows) else { return }
                userDefaults.set(encodedData, forKey: windowsStoreKey)
            }
        }
}
