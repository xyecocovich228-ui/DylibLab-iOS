import UIKit

/// Хелпер для проверки что оверлей-менюшки вообще могут показаться поверх стенда.
final class OverlayHost: NSObject {
    private override init() {}
    static var testWindow: UIWindow?
    static var testButton: UIButton?

    /// Слепок окон для детекта «меню создало новое окно»
    static func windowSnapshot() -> Set<String> {
        var set = Set<String>()
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for (i, w) in ws.windows.enumerated() {
                set.insert("\(type(of: w))#\(i):\(Int(w.bounds.width))x\(Int(w.bounds.height)):lvl\(w.windowLevel.rawValue)")
            }
        }
        return set
    }

    static func describeWindows() -> String {
        var lines: [String] = []
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for (i, w) in ws.windows.enumerated() {
                lines.append("window[\(i)] \(type(of: w)) frame=\(Int(w.bounds.width))x\(Int(w.bounds.height)) hidden=\(w.isHidden) alpha=\(w.alpha) level=\(w.windowLevel.rawValue) key=\(w.isKeyWindow)")
            }
        }
        return lines.isEmpty ? "(окон нет)" : lines.joined(separator: "\n")
    }

    /// Показывает тестовый плавающий оверлей — так проверяется что UIWindow поверх работает,
    /// жест перетаскивания жив, landscape не ломает координаты.
    static func showTestOverlay() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            Logger.shared.log(.err, tag: "OVERLAY", "Нет UIWindowScene — оверлей невозможен")
            return
        }
        if testWindow != nil {
            Logger.shared.log(.info, tag: "OVERLAY", "Тестовый оверлей уже показан — таскай красную кнопку по экрану")
            return
        }
        let win = UIWindow(windowScene: scene)
        win.frame = UIScreen.main.bounds
        win.windowLevel = UIWindow.Level.alert + 1
        win.backgroundColor = .clear
        win.isHidden = false

        let btn = UIButton(type: .system)
        btn.frame = CGRect(x: 60, y: 60, width: 180, height: 56)
        btn.setTitle("● TEST MENU", for: .normal)
        btn.backgroundColor = UIColor.red.withAlphaComponent(0.92)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 16)
        btn.layer.cornerRadius = 12
        btn.addTarget(self, action: #selector(testButtonTapped), for: .touchUpInside)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(testButtonDragged(_:)))
        btn.addGestureRecognizer(pan)

        win.addSubview(btn)
        // Подсказка
        let hint = UILabel(frame: CGRect(x: 60, y: 124, width: 320, height: 30))
        hint.text = "Таскай кнопку — так ведут себя менюшки"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 13)
        hint.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hint.layer.cornerRadius = 6
        hint.clipsToBounds = true
        hint.textAlignment = .center
        win.addSubview(hint)

        testWindow = win
        testButton = btn
        win.makeKeyAndVisible()
        Logger.shared.log(.ok, tag: "OVERLAY", "Тестовый оверлей ПОКАЗАН (UIWindow level alert+1). Таскай красную кнопку. Если твоя менюшка тоже делает UIWindow — она должна вести себя так же.")
        Logger.shared.log(.info, tag: "OVERLAY", "Окна сейчас:\n\(describeWindows())")
    }

    static func hideTestOverlay() {
        testWindow?.isHidden = true
        testWindow = nil
        testButton = nil
        Logger.shared.log(.info, tag: "OVERLAY", "Тестовый оверлей скрыт")
    }

    @objc private static func testButtonTapped() {
        Logger.shared.log(.info, tag: "OVERLAY", "Тап по тестовой кнопке прошёл ✓ — тачи до оверлея доходят")
    }

    @objc private static func testButtonDragged(_ g: UIPanGestureRecognizer) {
        guard let v = g.view, let superV = v.superview else { return }
        let t = g.translation(in: superV)
        v.center = CGPoint(x: v.center.x + t.x, y: v.center.y + t.y)
        g.setTranslation(.zero, in: superV)
        if g.state == .ended {
            Logger.shared.log(.info, tag: "OVERLAY", "Драг ок ✓ новая позиция \(Int(v.frame.origin.x)),\(Int(v.frame.origin.y)) — pan-жесты в оверлее работают")
        }
    }

    /// Проверка совместимости стенда с менюшками: landscape, сцена, keyWindow и т.д.
    static func compatibilityReport() -> String {
        var r: [String] = []
        let screen = UIScreen.main.bounds
        if screen.width > screen.height {
            r.append("Landscape OK: " + String(Int(screen.width)) + "x" + String(Int(screen.height)))
        } else {
            r.append("Portrait - поверни девайс! Стенд работает в landscape")
        }
        let hasScene = UIApplication.shared.connectedScenes.first is UIWindowScene
        r.append(hasScene ? "UIWindowScene активна OK" : "нет сцены FAIL")
        let allWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let hasKey = allWindows.contains(where: { $0.isKeyWindow })
        r.append("KeyWindow: " + (hasKey ? "есть" : "НЕТ - странно"))
        r.append("Окон всего: " + String(allWindows.count))
        r.append("Загружено dylib: " + String(DylibLoader.shared.loadedURLs.count))
        let docsOK = FileManager.default.fileExists(atPath: DylibStore.documentsDir().path)
        r.append("Документы доступны: " + (docsOK ? "да" : "нет"))
        return r.joined(separator: "\n")
    }
}
