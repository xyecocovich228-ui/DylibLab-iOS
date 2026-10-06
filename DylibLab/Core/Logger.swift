import Foundation

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case ok   = "OK"
    case warn = "WARN"
    case err  = "ERR"
}

struct LogEntry {
    let date: Date
    let level: LogLevel
    let tag: String
    let message: String

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func line() -> String {
        return "[\(Self.fmt.string(from: date))] [\(level.rawValue)] [\(tag)] \(message)"
    }
}

extension Notification.Name {
    static let DylibLabLogAdded = Notification.Name("DylibLabLogAdded")
}

/// Потокобезопасный логер. Всё что происходит с dylib — пишется сюда с меткой времени.
final class Logger {
    static let shared = Logger()
    private let queue = DispatchQueue(label: "lab.dylib.logger", qos: .utility)
    private var entries: [LogEntry] = []
    private let maxEntries = 3000

    var logFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dyliblab.log")
    }

    private init() {}

    func log(_ level: LogLevel, tag: String, _ message: String) {
        let e = LogEntry(date: Date(), level: level, tag: tag, message: message)
        queue.async {
            self.entries.append(e)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            // Дописываем в файл
            if let data = (e.line() + "\n").data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let h = try? FileHandle(forWritingTo: self.logFileURL) {
                        _ = try? h.seekToEnd()
                        try? h.write(contentsOf: data)
                        try? h.close()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .DylibLabLogAdded, object: e)
            }
        }
        // Дублируем в консоль Xcode — удобно смотреть через Console.app
        print(e.line())
    }

    func allEntries() -> [LogEntry] {
        queue.sync { entries }
    }

    func filtered(_ levels: Set<LogLevel>) -> [LogEntry] {
        queue.sync { levels.isEmpty ? entries : entries.filter { levels.contains($0.level) } }
    }

    func fullText(levels: Set<LogLevel> = []) -> String {
        let list = levels.isEmpty ? allEntries() : filtered(levels)
        let header = "DylibLab LOG · \(Date()) · записей: \(list.count)\n" + DeviceInfo.summary() + "\n\n"
        return header + list.map { $0.line() }.joined(separator: "\n")
    }

    func clear() {
        queue.async {
            self.entries.removeAll()
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
        log(.info, tag: "LOG", "Лог очищен пользователем")
    }
}
