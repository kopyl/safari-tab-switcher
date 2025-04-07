import SwiftUI
import KeyboardShortcuts
import SafariServices.SFSafariExtensionManager
import Combine

func getToolTipText() -> String {
    return "Click to avoid closing this panel when you release \(KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers.symbolRepresentation ?? "your modifier key/s")"
}

func switchTabs() async {
    let tabToSwitchToInSafari = appState.renderedTabs[appState.indexOfTabToSwitchTo]
    do {
        addSpecificTabToHistory(tab: tabToSwitchToInSafari)
        try await SFSafariApplication.dispatchMessage(
            withName: "switchtabto",
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: ["id": String(tabToSwitchToInSafari.id)]
        )
    } catch let error {
        log("Dispatching message to the extension resulted in an error: \(error)")
    }
}

func closeTab(tab: Tab) async {
    do {
        removeSpecificTabFromHistory(tab: tab)
        try await SFSafariApplication.dispatchMessage(
            withName: "closetab",
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: ["id": String(tab.id)]
        )
    } catch let error {
        log("Dispatching message to the extension resulted in an error: \(error)")
    }
}

func addSpecificTabToHistory(tab: Tab) {
    var windows = Store.windows
    guard var tabsMutated = windows.windows.last?.tabs else { return }

    tabsMutated.append(tab)

    let currentWindow = _Window(tabs: tabsMutated)
    windows.append(currentWindow)
    Store.windows = windows
}

func removeSpecificTabFromHistory(tab: Tab) {
    var windows = Store.windows
    guard var tabsMutated = windows.windows.last?.tabs else { return }
    
    tabsMutated = tabsMutated.filter { $0.id != tab.id }
    
    let currentWindow = _Window(tabs: tabsMutated)
    windows.append(currentWindow)
    Store.windows = windows
}

func hideTabsPanelAndSwitchTabs() {
    hideTabsPanel()
    guard !appState.renderedTabs.isEmpty else { return }
    Task{ await switchTabs() }
}

func renderTabsWithoutSearchQuery() {
    switch(appState.sortTabsBy) {
    case .asTheyAppearInBrowser:
        appState.renderedTabs = appState.savedTabs
            .enumerated()
            .map { index, _tab in
                var tab = _tab
                tab.renderIndex = tab.id
                return tab
            }
            .sorted { $0.id < $1.id }
    case .asTheyAppearInBrowserReversed:
        let tabsCount = appState.savedTabs.count
        appState.renderedTabs = appState.savedTabs
            .enumerated()
            .map { index, _tab in
                var tab = _tab
                tab.renderIndex = tabsCount - 1 - tab.id
                return tab
            }
            .sorted { $0.id < $1.id }
            .reversed()
    case .lastSeen:
        appState.renderedTabs = appState.savedTabs.reversed()
    }
}

func rerenderTabs() {
    if appState.searchQuery.isEmpty {
        renderTabsWithoutSearchQuery()
        return
    }
    
    let searchQuery = appState.searchQuery.lowercased()
    let searchWords = searchQuery.split(separator: " ").map { String($0) }

    let matchingTabs = appState.savedTabs.filter { tab in
        var title = tab.title
        if tab.host == "" && tab.title == "" {
            title = "no title"
        }
        
        let textToSearch = (tab.host + " " + title).lowercased()
        return searchWords.allSatisfy { textToSearch.contains($0) }
    }

    let scoredTabs = matchingTabs.map { tab -> (tab: Tab,     score: Int) in
        let host = tab.host.lowercased()
        
        var title = tab.title.lowercased()
        if tab.host == "" && tab.title == "" {
            title = "no title"
        }
        
        var score = 0

        
        func scoreForMatch(in text: String) -> Int {
            var matchScore = 0
            let textWords = text.split(separator: " ").map { String($0) }
            
            if searchWords.allSatisfy({ word in textWords.contains(where: { $0.contains(word) }) }) {
                matchScore += 1
            }

            if text.contains(searchQuery) {
                matchScore += 1
            } else {
                let orderedMatch = textWords.joined(separator: " ")
                if orderedMatch.contains(searchQuery) {
                    matchScore += 1
                }
            }
            return matchScore
        }
        
        score += scoreForMatch(in: host) * 1
        score += scoreForMatch(in: title + " " + host)

        let hostParts = host.split(separator: ".")
        let domainZone = hostParts.last ?? ""
        
        var domainParts: [String.SubSequence] = []
        var reversedDomainParts: [String.SubSequence] = []
        if !hostParts.isEmpty {
            domainParts = hostParts
            domainParts.removeLast()
            reversedDomainParts = domainParts.reversed()
        }
        
        var scoreMultiplier = 50
        for (index, part) in reversedDomainParts.enumerated() {
            if domainParts.count == 1 {
                scoreMultiplier = 20
            }
            else if index == 0 {
                scoreMultiplier = 10
            }
            else {
                scoreMultiplier = 1
            }
            
            if part == "" {
                continue
            }
            
            if part.starts(with: searchQuery) {
                score += 5 * scoreMultiplier
            }
            else if part.contains(searchQuery) {
                score += 2
            }
        }
        
        if score == 0 {
            if host.contains(searchQuery) {
                score += 1
            }
        }
        
        if domainZone.contains(searchQuery) {
            score += 1
        }

        return (tab, score)
    }

    let filteredAndSorted = scoredTabs
        .filter { $0.score > 0 }
        .sorted { $0.score > $1.score }
        .map { $0.tab }

    appState.renderedTabs = filteredAndSorted
        .enumerated()
        .map { index, tab in
            var updatedTab = tab
            updatedTab.renderIndex = index
            return updatedTab
        }
}

class Favicons: ObservableObject {
    @Published var icons: [String: NSImage] = [:]
    private var cache: Set<String> = []
    
    static let shared = Favicons()

    func fetchFavicon(for host: String) {
        if cache.contains(host) {
            return
        }
        cache.insert(host)

        let primaryURL = "https://icons.duckduckgo.com/ip3/\(host).ico"
        let fallbackURL = "https://www.google.com/s2/favicons?sz=32&domain=\(host)"

        fetchImage(from: primaryURL, for: host, fallbackURL: fallbackURL)
    }

    private func fetchImage(from urlString: String, for host: String, fallbackURL: String? = nil) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                
                if let fallbackURL = fallbackURL {
                    self.fetchImage(from: fallbackURL, for: host)
                }
                return
            }

            guard let data = data, let image = NSImage(data: data), error == nil else {
                return
            }

            DispatchQueue.main.async {
                self.icons[host] = image
            }
        }.resume()
    }
}

struct TabItemView: View {
    @ObservedObject var state = appState
    let tab: Tab
    
    var firstColumn: String {
        if tab.host == "" {
            return "No title"
        }
        switch appState.columnOrder {
        case .host_title:
            return tab.host
        case .title_host:
            return tab.title
        }
    }
    var secondColumn: String {
        switch appState.columnOrder {
        case .host_title:
            return tab.title
        case .title_host:
            return tab.host
        }
    }
    
    @StateObject private var favicons = Favicons.shared
    
    @Environment(\.colorScheme) private var colorScheme
    
    var lightGreyInDarkAppearance: Color = .white.opacity(0.1)
    var lightGreyInLightAppearance: Color = .black.opacity(0.1)
    var lightGrey: Color {
        colorScheme == .dark ? lightGreyInDarkAppearance : lightGreyInLightAppearance
    }
    
    var greyInDarkAppearance: Color = .white.opacity(0.8)
    var greyInLightAppearance: Color = .black.opacity(0.5)
    var grey: Color {
        colorScheme == .dark ? greyInDarkAppearance : greyInLightAppearance
    }
    
    func placeholderImage(tab: Tab) -> some View {
        Text(tab.host.first?.uppercased() ?? "N")
            .opacity(0.7)
            .font(.system(size: 10))
            .frame(width: 16, height: 16)
            .background(lightGrey)
            .cornerRadius(3)
    }
    
    var body: some View {
        HStack(alignment: .center) {
        Group {
            if tab.host == "" {
                placeholderImage(tab: tab)
            }
            else if let image = favicons.icons[tab.host] {
                Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
            } else {
                placeholderImage(tab: tab)
                .onAppear {
                    favicons.fetchFavicon(for: tab.host)
                }
            }
        }
        .padding(.trailing, 12)
            
            Text(firstColumn)
                .font(.system(size: 18))
                .foregroundStyle(
                    tab.renderIndex == state.indexOfTabToSwitchTo ? .currentTabFg : .currentTabFg.opacity(0.65)
                )
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            Text(secondColumn)
                .font(.system(size: 13))
                .foregroundStyle(
                    tab.renderIndex == state.indexOfTabToSwitchTo ? .currentTabFg : .currentTabFg.opacity(0.65)
                )
                .frame(minWidth: 0, maxWidth: state.columnOrder == .host_title ? .infinity : 200, alignment: .leading)
        }
        .lineLimit(1)
        .padding(.top, 18).padding(.bottom, 18)
        .padding(.leading, 21).padding(.trailing, 41)
        .background(
            .currentTabBg.opacity(tab.renderIndex == state.indexOfTabToSwitchTo ? 1 : 0)
        )
        .id(tab.renderIndex)
        .cornerRadius(6)
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .transition(.move(edge: .bottom))
        .onTapGesture {
            state.indexOfTabToSwitchTo = tab.renderIndex
            hideTabsPanelAndSwitchTabs()
        }
    }
}
