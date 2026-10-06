import Foundation

/// Папки-песочницы для dylib.
enum DylibStore {
    static func documentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static func dylibsDir() -> URL {
        documentsDir().appendingPathComponent("Dylibs", isDirectory: true)
    }
    static func ensureDirectories() {
        let dir = dylibsDir()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            Logger.shared.log(.info, tag: "STORE", "Создана папка \(dir.path)")
        }
    }

    /// Все кандидаты: Documents/Dylibs + встроенные в bundle (если положили через Xcode / injector).
    static func listCandidates() -> [URL] {
        ensureDirectories()
        var out: [URL] = []
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: dylibsDir(),
                                                   includingPropertiesForKeys: [.fileSizeKey],
                                                   options: [.skipsHiddenFiles]) {
            out += files.filter { ["dylib", "so", "bundle"].contains($0.pathExtension.lowercased()) }
            // .framework папки тоже считаем
            out += files.filter { $0.pathExtension.lowercased() == "framework" }
        }
        // Встроенные: корень bundle + Frameworks
        if let bundled = Bundle.main.urls(forResourcesWithExtension: "dylib", subdirectory: nil) {
            out += bundled
        }
        if let fwPath = Bundle.main.privateFrameworksPath {
            let fwURL = URL(fileURLWithPath: fwPath)
            if let inner = try? fm.contentsOfDirectory(at: fwURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                out += inner.filter { $0.pathExtension == "dylib" }
            }
        }
        return out
    }

    static func bundledDylibNames() -> [String] {
        (Bundle.main.urls(forResourcesWithExtension: "dylib", subdirectory: nil) ?? []).map { $0.lastPathComponent }
    }
}
