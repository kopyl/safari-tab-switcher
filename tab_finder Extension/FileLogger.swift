import Foundation
import os.log

class FileLogger {
    static let shared = FileLogger()
    private let logFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsURL.appendingPathComponent("SafariExtensionLogs.txt")

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
    }

    func log(_ message: String) {
        let timestamp = Date().description(with: .current)
        let logMessage = "[\(timestamp)] \(message)\n"
        os_log("%{public}@", message)
        appendToFile(logMessage)
    }

    private func appendToFile(_ text: String) {
        if let data = text.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? text.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
