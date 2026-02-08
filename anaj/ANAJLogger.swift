#if os(macOS)
import Foundation

final class ANAJLogger {
    static let shared = ANAJLogger()

    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    private let queue = DispatchQueue(label: "anaj.logger.queue", qos: .utility)
    private let formatter: ISO8601DateFormatter
    private let fileURL: URL

    private init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter

        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library", isDirectory: true)
        let logsDir = library.appendingPathComponent("Logs/ANAJ", isDirectory: true)
        self.fileURL = logsDir.appendingPathComponent("openclaw.log", isDirectory: false)

        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
            }
        } catch {
            print("ANAJLogger setup failed: \(error)")
        }
    }

    func debug(_ category: String, _ message: String, requestID: String? = nil, metadata: [String: String] = [:]) {
        log(.debug, category: category, message: message, requestID: requestID, metadata: metadata)
    }

    func info(_ category: String, _ message: String, requestID: String? = nil, metadata: [String: String] = [:]) {
        log(.info, category: category, message: message, requestID: requestID, metadata: metadata)
    }

    func warn(_ category: String, _ message: String, requestID: String? = nil, metadata: [String: String] = [:]) {
        log(.warning, category: category, message: message, requestID: requestID, metadata: metadata)
    }

    func error(_ category: String, _ message: String, requestID: String? = nil, metadata: [String: String] = [:]) {
        log(.error, category: category, message: message, requestID: requestID, metadata: metadata)
    }

    private func log(_ level: Level, category: String, message: String, requestID: String?, metadata: [String: String]) {
        let timestamp = formatter.string(from: Date())
        let requestComponent = requestID.map { " [req:\($0)]" } ?? ""
        let metadataComponent: String
        if metadata.isEmpty {
            metadataComponent = ""
        } else {
            let pairs = metadata
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            metadataComponent = " | \(pairs)"
        }
        let line = "\(timestamp) [\(level.rawValue)] [\(category)]\(requestComponent) \(message)\(metadataComponent)\n"

        queue.async { [fileURL] in
            if let data = line.data(using: .utf8) {
                do {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } catch {
                    print("ANAJLogger write failed: \(error)")
                }
            }
            print(line.trimmingCharacters(in: .newlines))
        }
    }
}
#endif
