import InputMethodKit

func getInputSourcesWithIDs() -> [(TISInputSource, String, Int)] {
    let selectableIsProperties = [
        kTISPropertyInputSourceType: kTISTypeKeyboardLayout as CFString,
    ] as CFDictionary
    
    let inputSourceArray = TISCreateInputSourceList(selectableIsProperties, false).takeRetainedValue() as! [TISInputSource]
    
    return inputSourceArray.map { source in
        let nameProperty = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        let name = nameProperty != nil ? Unmanaged<CFString>.fromOpaque(nameProperty!).takeUnretainedValue() as String : "Unknown"
        
        let description = String(describing: source)
        var layoutID = -9999
        
        if let idRange = description.range(of: "id=") {
            let afterIDRange = description[idRange.upperBound...]
            if let endParenRange = afterIDRange.range(of: ")") {
                let idString = description[idRange.upperBound..<endParenRange.lowerBound]
                if let extractedID = Int(idString) {
                    layoutID = extractedID
                }
            }
        }
        
        return (source, name, layoutID)
    }
}

func getInputSourcesSortedByHistory() -> [TISInputSource] {
    guard let userDefaults = UserDefaults(suiteName: "com.apple.HIToolbox"),
          let inputSourceHistory = userDefaults.array(forKey: "AppleInputSourceHistory") as? [[String: Any]] else {
        return []
    }
    
    let inputSourceArray = getInputSourcesWithIDs()
    
    var inputSourcesSortedByHistory: [TISInputSource] = []
    
    for item in inputSourceHistory {
        guard let layoutID = item["KeyboardLayout ID"] else { return []}

        for inputSource in inputSourceArray {
            if inputSource.2 == layoutID as! Int {
                inputSourcesSortedByHistory.append(inputSource.0)
            }
        }
    }

    return inputSourcesSortedByHistory
}

func changeInputSource(inputSource: TISInputSource) {
    TISSelectInputSource(inputSource)
}

func selectPreviousInputSource() {
    let inputSources = getInputSourcesSortedByHistory()
    guard inputSources.count > 1 else { return }
    let prevInputSource = inputSources[1]
    changeInputSource(inputSource: prevInputSource)
    appState.currentInputSourceName = getCurrentInputSourceName()
}

func getCurrentInputSourceName() -> String {
    let currentInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let nameProperty = TISGetInputSourceProperty(currentInputSource, kTISPropertyLocalizedName)
    let name = nameProperty != nil ? Unmanaged<CFString>.fromOpaque(nameProperty!).takeUnretainedValue() as String : "Unknown"
    return name
}
