import SwiftUI
import KeyboardShortcuts
import SafariServices.SFSafariExtensionManager

func getToolTipText() -> String {
    return "Click to avoid closing this panel when you release \(KeyboardShortcuts.Name.openTabsList.shortcut?.modifiers.symbolRepresentation ?? "your modifier key/s")"
}

func switchTabs() async {
    let tabToSwitchToInSafari = appState.renderedTabs[appState.indexOfTabToSwitchTo]
    let tabURL = tabToSwitchToInSafari.url ?? URL(string: "httos://google.con")!
    
    do {
        addSpecificTabToHistory(tab: tabToSwitchToInSafari)
        try await SFSafariApplication.dispatchMessage(
            withName: "switchtabto",
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: ["id": String(tabToSwitchToInSafari.id), "url": tabURL.absoluteString]
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

func getOpenTabsDependingOnSorting() -> [Tab] {
    switch(appState.sortTabsBy) {
    case .asTheyAppearInBrowser:
        return appState.savedOpenTabs
            .enumerated()
            .map { index, _tab in
                var tab = _tab
                tab.renderIndex = tab.id
                return tab
            }
            .sorted { $0.id < $1.id }
    case .asTheyAppearInBrowserReversed:
        let tabsCount = appState.savedOpenTabs.count
        return appState.savedOpenTabs
            .enumerated()
            .map { index, _tab in
                var tab = _tab
                tab.renderIndex = tabsCount - 1 - tab.id
                return tab
            }
            .sorted { $0.id < $1.id }
            .reversed()
    case .lastSeen:
        return appState.savedOpenTabs.reversed()
    }
}

func performSearch(on tabs: [Tab]) -> [Tab] {
    let searchQuery = appState.searchQuery.lowercased()
    let searchWords = searchQuery.split(separator: " ").map { String($0) }
    
    let matchingTabs = tabs.filter { tab in
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
        
        if title.starts(with: searchQuery) {
            score += 5
        }
        
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
    
    return filteredAndSorted
        .enumerated()
        .map { index, tab in
            var updatedTab = tab
            updatedTab.renderIndex = index
            return updatedTab
        }
}

func updateRenderIndices() {
    for idx in appState.renderedTabs.indices {
        appState.renderedTabs[idx].renderIndex = idx
    }
}

func prepareTabsForRender() {
    var openTabsToRender: [Tab]
    var closedTabsToRender: [Tab]
    
    if appState.searchQuery.isEmpty {
        openTabsToRender = getOpenTabsDependingOnSorting()
        closedTabsToRender = Store.VisitedPagesHistory.loadAll()
    }
    else {
        var visibleOpenTabsToPerformSearchOn = appState.savedOpenTabs
        #if LITE
        visibleOpenTabsToPerformSearchOn = getTabsDependingOnSorting().prefix(5)
        #endif

        openTabsToRender = performSearch(on: visibleOpenTabsToPerformSearchOn)
        closedTabsToRender = performSearch(on: Store.VisitedPagesHistory.loadAll())
    }
    

    closedTabsToRender = closedTabsToRender
        .filter { tab in
            !openTabsToRender.contains { $0.url == tab.url }
        }
    
    appState.openTabsRenderedCount = openTabsToRender.count
    appState.closedTabsRenderedCount = closedTabsToRender.count
    
    appState.renderedTabs = openTabsToRender + closedTabsToRender
    
    updateRenderIndices()
}
