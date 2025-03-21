import Foundation
import SafariServices

struct _Window: Codable {
    var tabs: Tabs
    var combinedID: String
    
    init(tabs: Tabs) {
        self.tabs = tabs
        self.combinedID = "-" + tabs.sorted{$0.id > $1.id}.map(\.title).joined()
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

func formatHost(_ host: String) -> String {
    return host
        .replacingOccurrences(of: "www.", with: "", options: NSString.CompareOptions.literal, range: nil)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

struct TabForSearch: Identifiable {
    var id: Int
    var safariID: Int
    var title: String
    var host: String
    var hostParts: [String.SubSequence] = []
    var domainZone: String.SubSequence = ""
    var searchRating: Int = 0
    
    init(tab: Tab, id: Int){
        self.id = id
        safariID = tab.id
        title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        host = tab.host == "" && title == "" ? "No title" : formatHost(tab.host)

        hostParts = host.split(separator: ".")
        domainZone = hostParts.last ?? ""
        guard !hostParts.isEmpty else { return }
        hostParts.removeLast()  /// need to change it for domain zones like com.ua?
        hostParts = hostParts.reversed()
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
    
    init(tab: TabForSearch) {
        self.id = tab.safariID
        self.title = tab.title
        self.host = tab.host
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
    public static let userDefaults = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    private static let windowsStoreKey = "windows"
    public static let isTabsSwitcherNeededToStayOpenStoreKey = "isTabsSwitcherNeededToStayOpen"

    public static let userSelectedAccentColorStoreKey = "userSelectedAccentColor"
    public static let userSelectedAccentColorDefaultValue = "#191919"

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
    
    static var isTabsSwitcherNeededToStayOpen: Bool {
        userDefaults.bool(forKey: isTabsSwitcherNeededToStayOpenStoreKey)
    }
}
