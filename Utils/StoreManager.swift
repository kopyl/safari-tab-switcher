import Foundation
import SafariServices

enum IncremetalTabProperty {
    case timesCreatedNewTabWithThisPage
    case timesSwitchedToWhileHavingHostTabOpen
}

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

struct Tab: Codable, Identifiable, Hashable {
    var id: Int
    var renderIndex: Int
    var title: String = ""
    public var url: URL?
    
    public var host: String {
        get {
            formatHost(url?.host ?? "")
        }
    }
    
    init(id: Int, tab: SFSafariTab) async {
        self.id = id
        self.renderIndex = 0
        await setTitleAndHostFromTab(tab: tab)
    }
    
    init(visitedPage: VisitedPagesHistoryModel) {
        self.id = -1
        self.renderIndex = 0
        self.title = visitedPage.title
        self.url = visitedPage.url
    }
    
    mutating func setTitleAndHostFromTab(tab: SFSafariTab) async {
        if let activePage = await tab.activePage() {
            if let properties = await activePage.properties() {
                title = properties.title ?? "No title"
                url = properties.url
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
    case lastSeenGroupedByHost = "Last seen grouped by host"
}

enum ColumnOrder: String, CaseIterable {
    case host_title = "host | title"
    case title_host = "title | host"
    
}

struct Store {
    public static let userDefaults = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    private static let windowsStoreKey = "windows"
    public static let isTabsSwitcherNeededToStayOpenStoreKey = "isTabsSwitcherNeededToStayOpen"
    public static let isTabsSwitcherNeededToStayOpenDefaultvalue = true

    public static let sortTabsByStoreKey = "sortTabsBy"
    public static let sortTabsByDefaultValue: SortTabsBy = .lastSeen
    
    public static let columnOrderStoreKey = "columnOrder"
    public static let columnOrderDefaultValue: ColumnOrder = .host_title

    public static let userSelectedAccentColorStoreKey = "userSelectedAccentColor"
    public static let userSelectedAccentColorDefaultValue = "#191919"
    
    public static let moveAppOutOfBackgroundWhenSafariClosesStoreKey = "moveAppOutOfBackgroundWhenSafariCloses"
    public static let moveAppOutOfBackgroundWhenSafariClosesDefaultValue = true
    
    public static let addStatusBarItemWhenAppMovesInBackgroundStoreKey = "addStatusBarItemWhenAppMovesInBackground"
    public static let addStatusBarItemWhenAppMovesInBackgroundDefaultValue = true

    public static let shallSafariIconBeTransparentStoreKey = "shallSafariIconBeTransparent"
    public static let shallSafariIconBeTransparentDefaultValue = false
    
    public static let isKeyboardShortcutGlobalStoreKey = "isKeyboardShortcutGlobal"
    public static let isKeyboardShortcutGlobalDefaultValue = false

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
        get {
            userDefaults.bool(forKey: isTabsSwitcherNeededToStayOpenStoreKey)
        }
        set {
            userDefaults.set(newValue, forKey: isTabsSwitcherNeededToStayOpenStoreKey)
        }
    }
    
    static var sortTabsBy: SortTabsBy {
        SortTabsBy(rawValue: userDefaults.string(forKey: sortTabsByStoreKey) ?? sortTabsByDefaultValue.rawValue) ?? sortTabsByDefaultValue
    }
    
    static var columnOrder: ColumnOrder {
        ColumnOrder(rawValue: userDefaults.string(forKey: columnOrderStoreKey) ?? columnOrderDefaultValue.rawValue) ?? columnOrderDefaultValue
    }
    
    static var moveAppOutOfBackgroundWhenSafariCloses: Bool {
        userDefaults.bool(forKey: moveAppOutOfBackgroundWhenSafariClosesStoreKey)
    }
    
    static var addStatusBarItemWhenAppMovesInBackground: Bool {
        get {
            userDefaults.bool(forKey: addStatusBarItemWhenAppMovesInBackgroundStoreKey)
        }
        set {
            userDefaults.set(newValue, forKey: addStatusBarItemWhenAppMovesInBackgroundStoreKey)
        }
    }
    
    static var userSelectedAccentColor: String {
        userDefaults.string(forKey: userSelectedAccentColorStoreKey) ?? userSelectedAccentColorDefaultValue
    }
    
    static var shallSafariIconBeTransparent: Bool {
        get {
            userDefaults.bool(forKey: shallSafariIconBeTransparentStoreKey)
        }
        set {
            userDefaults.set(newValue, forKey: shallSafariIconBeTransparentStoreKey)
        }
    }
    
    static var isKeyboardShortcutGlobal: Bool {
        get {
            userDefaults.bool(forKey: isKeyboardShortcutGlobalStoreKey)
        }
        set {
            userDefaults.set(newValue, forKey: isKeyboardShortcutGlobalStoreKey)
        }
    }
    
    class VisitedPagesHistory {
        
        static let persistentContainer = getCoreDataContainer()
        
        static func getCoreDataContainer() -> NSPersistentContainer {
            let container = NSPersistentContainer(name: visitedPagesHistoryModelName)

                // 📍 Redirect store to App Group container
                guard let sharedStoreURL = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
                    .appendingPathComponent("\(visitedPagesHistoryModelName).sqlite") else {
                        fatalError("❌ Unable to locate App Group container")
                }

                let storeDescription = NSPersistentStoreDescription(url: sharedStoreURL)
                container.persistentStoreDescriptions = [storeDescription]

                container.loadPersistentStores { _, error in
                    if let error = error {
                        fatalError("❌ Failed to load store: \(error)")
                    }
                    
                    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                }

                return container
        }
        
        static func getBackgroundContext() -> NSManagedObjectContext {
            let context = persistentContainer.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return context
        }
        
        static func loadAll() -> [Tab] {
            let context = persistentContainer.viewContext
            let request: NSFetchRequest<VisitedPagesHistoryModel> = VisitedPagesHistoryModel.fetchRequest()
            
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

            do {
                return try context.fetch(request).map(Tab.init)
            } catch {
                log("❌ Fetch error: \(error)")
                return []
            }
        }
        
        static func saveOne(url: URL, title: String) {
            let context = getBackgroundContext()
            
            context.perform {
                let tab = VisitedPagesHistoryModel(context: context)

                tab.url = url
                tab.title = title
                tab.createdAt = Date()
                tab.updatedAt = Date()
                tab.timesUpdated = 0
                tab.timesCreatedNewTabWithThisPage = 0
                tab.timesSwitchedToWhileHavingHostTabOpen = 0

                do {
                    try context.save()
                } catch {
                    log("❌ Failed to save tab: \(error)")
                }
            }
        }
        
        static func removeAll() {
            let context = persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = VisitedPagesHistoryModel.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
                try context.save()
                log("✅ All tabs deleted")
            } catch {
                log("❌ Batch delete failed: \(error)")
            }
        }
        
        static func removeTabsWithLowUpdateCount(threshold: Int = 100) {
            let context = persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = VisitedPagesHistoryModel.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "timesUpdated < %d", threshold)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                try context.save()
                
                if let count = result?.result as? Int {
                    log("✅ Deleted \(count) tabs with timesUpdated < \(threshold)")
                } else {
                    log("✅ Deleted tabs with timesUpdated < \(threshold)")
                }
            } catch {
                log("❌ Failed to delete tabs with low update count: \(error)")
            }
        }
        
        static func removeOldTabs(olderThanDays: Int = 30) {
            let context = persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = VisitedPagesHistoryModel.fetchRequest()
            
            let calendar = Calendar.current
            guard let cutoffDate = calendar.date(byAdding: .day, value: -olderThanDays, to: Date()) else {
                log("❌ Failed to calculate cutoff date")
                return
            }
            
            fetchRequest.predicate = NSPredicate(format: "updatedAt < %@", cutoffDate as NSDate)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                try context.save()
                
                if let count = result?.result as? Int {
                    log("✅ Deleted \(count) tabs older than \(olderThanDays) days")
                } else {
                    log("✅ Deleted tabs older than \(olderThanDays) days")
                }
            } catch {
                log("❌ Failed to delete old tabs: \(error)")
            }
        }
        
        static func deleteCoreDataStore() {
            guard let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                    log("❌ App Group container not found")
                    return
            }

            let fileManager = FileManager.default
            let baseFilename = "\(visitedPagesHistoryModelName).sqlite"
            let urlsToDelete = [
                containerURL.appendingPathComponent(baseFilename),
                containerURL.appendingPathComponent(baseFilename + "-shm"),
                containerURL.appendingPathComponent(baseFilename + "-wal")
            ]

            for url in urlsToDelete {
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        try fileManager.removeItem(at: url)
                        log("🗑️ Deleted: \(url.lastPathComponent)")
                    } catch {
                        log("❌ Could not delete \(url.lastPathComponent): \(error)")
                    }
                } else {
                    print("ℹ️ Not found: \(url.lastPathComponent)")
                }
            }
        }
        
        static func tabDoesExist(with url: URL) -> Bool {
            let context = persistentContainer.viewContext
            let request: NSFetchRequest<NSFetchRequestResult> = VisitedPagesHistoryModel.fetchRequest()
            request.predicate = NSPredicate(format: "url == %@", url as CVarArg)
            request.fetchLimit = 1
            request.resultType = .countResultType

            do {
                let count = try context.count(for: request)
                return count > 0
            } catch {
                log("❌ Failed to check existence: \(error)")
                return false
            }
        }
        
        static func updateOne(
            url: URL,
            newTitle: String? = nil,
            incrementTabProperty: IncremetalTabProperty? = nil
        ) {
            let context = getBackgroundContext()
            let request: NSFetchRequest<VisitedPagesHistoryModel> = VisitedPagesHistoryModel.fetchRequest()
            request.predicate = NSPredicate(format: "url == %@", url as CVarArg)
            request.fetchLimit = 1

            context.perform {
                do {
                    guard let tab = try context.fetch(request).first else {
                        log("No tab found with url \(url)")
                        return
                    }
                
                    if let newTitle = newTitle {
                        tab.title = newTitle
                    }
                    switch incrementTabProperty {
                    case .timesSwitchedToWhileHavingHostTabOpen:
                        tab.timesSwitchedToWhileHavingHostTabOpen += 1
                    case .timesCreatedNewTabWithThisPage:
                        tab.timesCreatedNewTabWithThisPage += 1
                    case nil:
                        break
                    }
                    tab.updatedAt = Date()
                    tab.timesUpdated += 1
                    
                    try context.save()
                } catch {
                    log("❌ Failed to update tab. Error: \(error). Predicate: \(String(describing: request.predicate ?? nil))")
                    
                    #if DEBUG
                    DispatchQueue.main.async {
                        guard let sound = NSSound(named: NSSound.Name("Basso.aiff")) else { return }
                        sound.stop()
                        sound.play()
                    }
                    #endif
                }
            }
        }
    }
}
