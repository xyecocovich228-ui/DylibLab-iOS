import UIKit

/// Короткая сводка об устройстве для шапки логов и экрана Инфо.
enum DeviceInfo {
    static func summary() -> String {
        let dev = UIDevice.current
        let bid = Bundle.main.bundleIdentifier ?? "unknown"
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "iOS " + dev.systemVersion + " " + dev.model + " " + dev.name + " bundle " + bid + " v" + ver
    }

    static func detailed() -> String {
        let dev = UIDevice.current
        let screen = UIScreen.main.bounds
        var lines: [String] = []
        lines.append("Устройство: " + dev.name + " (" + dev.model + ")")
        lines.append("Система: " + dev.systemName + " " + dev.systemVersion)
        lines.append("Экран: " + String(Int(screen.width)) + "x" + String(Int(screen.height)) + " scale " + String(describing: UIScreen.main.scale))
        if screen.width > screen.height {
            lines.append("Ориентация: landscape OK")
        } else {
            lines.append("Ориентация: portrait - поверни девайс")
        }
        let bid = Bundle.main.bundleIdentifier ?? "unknown"
        lines.append("Bundle: " + bid)
        lines.append("Документы: " + DylibStore.documentsDir().path)
        lines.append("Dylibs: " + DylibStore.dylibsDir().path)
        if JailbreakCheck.isJailbroken() {
            lines.append("Jailbreak: ДА")
        } else {
            lines.append("Jailbreak: НЕТ (нужна подпись для dlopen)")
        }
        return lines.joined(separator: "\n")
    }
}

/// Примитивная проверка джейла — влияет на то, загрузится ли unsigned dylib.
enum JailbreakCheck {
    static func isJailbroken() -> Bool {
        let paths = ["/Applications/Cydia.app", "/bin/bash", "/usr/sbin/sshd",
                     "/etc/apt", "/private/var/lib/apt", "/var/jb"]
        if paths.contains(where: { FileManager.default.fileExists(atPath: $0) }) { return true }
        if UIApplication.shared.canOpenURL(URL(string: "cydia://package/com.example.package")!) { return true }
        // Попытка записи за пределы песочницы
        let test = "/private/jb_test_\(Int.random(in: 0...9999)).txt"
        do {
            try "test".write(toFile: test, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: test)
            return true
        } catch { return false }
    }
}
