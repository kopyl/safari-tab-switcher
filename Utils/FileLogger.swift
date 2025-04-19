import Foundation
import os.log
import Cocoa

final class FileLogger {
    static let shared = FileLogger()

    private let filename = "tab-finder-log-file.txt"
    private let bookmarkDataKey = "securityScopedBookmarkData"
    private let defaultPath = NSString(string: "~/Downloads").expandingTildeInPath
    private var logFileURL: URL

    private init() {
        logFileURL = URL(fileURLWithPath: defaultPath).appendingPathComponent(filename)
        
        if let bookmark = UserDefaults.standard.data(forKey: bookmarkDataKey),
           let baseURL = resolveBookmark(bookmark) {
            logFileURL = baseURL.appendingPathComponent(filename)
        } else if let newBookmark = requestAccessToDirectory(),
                  let baseURL = resolveBookmark(newBookmark) {
            logFileURL = baseURL.appendingPathComponent(filename)
            UserDefaults.standard.set(newBookmark, forKey: bookmarkDataKey)
        } else {
            showError("No access to folder.")
            logFileURL = URL(fileURLWithPath: defaultPath).appendingPathComponent(filename)
        }

        createNewEmptyLogFile()
    }

    private func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        do {
            let baseURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            guard baseURL.startAccessingSecurityScopedResource() else {
                showError("Failed to access security-scoped resource.")
                return nil
            }
            return baseURL
        } catch {
            showError("Bookmark error: \(error)")
            return nil
        }
    }

    private func requestAccessToDirectory() -> Data? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: defaultPath)
        panel.message = "Please grant access to the folder for log storage"
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            showError("Failed to create bookmark: \(error)")
            return nil
        }
    }

    private func createNewEmptyLogFile() {
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                try FileManager.default.removeItem(at: logFileURL)
            }
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            showError("Failed to create log file: \(error)")
        }
    }

    func log(_ message: Any...) {
        let timestamp = Date().description(with: .current)
        let messageText = message.map { String(describing: $0) }.joined(separator: " ")
        let logMessage = "[\(timestamp)] \(messageText)\n"
        os_log("%{public}@", "\(messageText)")
        appendToFile(logMessage)
    }

    private func appendToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? text.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

let log = FileLogger.shared.log
