import SwiftUI
import KeyboardShortcuts
import SafariServices.SFSafariExtensionManager

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
