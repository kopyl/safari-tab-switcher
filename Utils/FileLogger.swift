import Foundation
import os.log

class FileLogger {
    static let shared = FileLogger()
    private let logFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsURL.appendingPathComponent("SafariExtensionLogs.txt")
        log("Logger file created at \(logFileURL.path)")

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
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

let log = FileLogger.shared.log
