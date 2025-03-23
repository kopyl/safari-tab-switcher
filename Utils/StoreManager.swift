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

struct Tab: Codable, Identifiable {
    var id: Int
    var lastSeen: Int
    var title: String = ""
    var host: String = "No title"
    
    init(id: Int, tab: SFSafariTab) async {
        self.id = id
        self.lastSeen = 0
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

enum SortTabsBy: String, CaseIterable {
    case lastSeen = "Last seen"
    case asTheyAppearInBrowser = "As they appear in browser"
    case asTheyAppearInBrowserReversed = "As they appear in browser (reversed)"
}

struct Store {
    public static let userDefaults = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    private static let windowsStoreKey = "windows"
    public static let isTabsSwitcherNeededToStayOpenStoreKey = "isTabsSwitcherNeededToStayOpen"

    public static let sortTabsByStoreKey = "sortTabsBy"
    public static let sortTabsByDefaultValue: SortTabsBy = .lastSeen

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
    
    static var sortTabsBy: SortTabsBy {
        SortTabsBy(rawValue: userDefaults.string(forKey: sortTabsByStoreKey) ?? sortTabsByDefaultValue.rawValue) ?? sortTabsByDefaultValue
    }
}
