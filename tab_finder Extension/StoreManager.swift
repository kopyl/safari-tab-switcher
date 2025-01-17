import Foundation
import SafariServices

struct TabInfo: Codable, Hashable {
    var id: Int
    var title: String = "No title"
    var host: String = ""
    
    init(id: Int, title: String = "", host: String = "") {
        self.id = id
        self.title = title
        self.host = host
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

struct Store {
    private static let userDefaults = UserDefaults(suiteName: "com.tabfinder.sharedgroup") ?? UserDefaults.standard

    static var tabs: OrderedSet<TabInfo> {
            get {
                guard let data = userDefaults.data(forKey: "tabs") else {
                    return OrderedSet([])
                }

                let decoder = JSONDecoder()
                let decodedTabs = (try? decoder.decode([TabInfo].self, from: data)) ?? []
                return OrderedSet(decodedTabs)
            }
            set {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(OrderedSet(newValue.elements).elements) {
                    userDefaults.set(data, forKey: "tabs")
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
