import Foundation
import Darwin

struct LoadedDylib {
    let url: URL
    let handle: UnsafeMutableRawPointer
    let loadedAt: Date
}

extension Notification.Name {
    static let DylibLabLoadedListChanged = Notification.Name("DylibLabLoadedListChanged")
}

/// Загрузчик .dylib через dlopen с подробным логом каждого шага:
/// что пошло не так, почему и на каком моменте.
final class DylibLoader {
    static let shared = DylibLoader()
    private var loaded: [String: LoadedDylib] = [:]
    private let lock = NSLock()
    private init() {}

    var loadedURLs: [URL] {
        lock.lock(); defer { lock.unlock() }
        return loaded.values.map { $0.url }
    }

    // MARK: - Главная точка входа

    /// Грузит один файл. Все этапы логируются: файл → Mach-O → подпись → dlopen → оверлей.
    func load(url: URL, autoload: Bool = false) {
        let tag = "DLOPEN"
        let name = url.lastPathComponent
        Logger.shared.log(.info, tag: tag, "─── Загрузка \(name) ───")
        Logger.shared.log(.info, tag: tag, "Момент 1/5 · путь: \(url.path)")

        // --- 1. Файл существует / доступен ---
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            Logger.shared.log(.err, tag: tag, "Момент 1/5 ✕ ФАЙЛ НЕ НАЙДЕН. Почему: путь неверный или файл удалён. Что делать: проверь вкладку Файлы / импортируй заново.")
            return
        }
        let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        Logger.shared.log(.info, tag: tag, "Момент 1/5 ✓ файл есть, размер \(size) байт")

        if size < 4096 {
            Logger.shared.log(.warn, tag: tag, "Подозрительно маленький размер (\(size)). Возможно это текстовый файл переименованный в .dylib")
        }
        if size == 0 {
            Logger.shared.log(.err, tag: tag, "Момент 1/5 ✕ ФАЙЛ ПУСТОЙ. Почему: не докачался / ошибка копирования. Решение: перекинь файл заново через Files / AirDrop.")
            return
        }

        // --- 2. Mach-O / архитектура ---
        Logger.shared.log(.info, tag: tag, "Момент 2/5 · проверка Mach-O заголовка…")
        switch MachoInspector.inspect(url: url) {
        case .success(let info):
            Logger.shared.log(.info, tag: tag, "Момент 2/5 · \(info.rawDescription) · размер \(info.fileSize)")
            if !info.archs.contains("arm64") {
                let archList = info.archs.joined(separator: ",")
                Logger.shared.log(.err, tag: tag, "Момент 2/5. НЕ ТА АРХИТЕКТУРА (" + archList + "). Почему: dylib собран для симулятора (x86_64) или для Mac. На iPhone нужен arm64. Решение: пересобери dylib с -arch arm64. Дальше dlopen не пробуем.")
                return
            }
            if !info.looksLikeDylib {
                Logger.shared.log(.warn, tag: tag, "Момент 2/5 ⚠ filetype не DYLIB. Продолжаем — вдруг это bundle, но dlopen может упасть.")
            } else {
                Logger.shared.log(.ok, tag: tag, "Момент 2/5 ✓ архитектура arm64, формат похож на dylib")
            }
        case .failure(let e):
            Logger.shared.log(.err, tag: tag, "Момент 2/5 ✕ НЕ MACH-O: \(e.localizedDescription). Почему: это не бинарник (текст, zip, ipa?). Решение: проверь чем собран файл, пересобери как dynamic library.")
            return
        }

        // --- 3. Подпись (важно для нон-джейл) ---
        Logger.shared.log(.info, tag: tag, "Момент 3/5 · проверка окружения подписи…")
        let jb = JailbreakCheck.isJailbroken()
        let bid = Bundle.main.bundleIdentifier ?? "unknown"
        let jbText = jb ? "ДА" : "НЕТ"
        Logger.shared.log(.info, tag: tag, "Момент 3/5 · джейлбрейк: " + jbText + " bundle: " + bid)
        if !jb {
            Logger.shared.log(.warn, tag: tag, "Момент 3/5 ⚠ Без джейла iOS требует ПОДПИСЬ dylib тем же сертификатом что и приложение. Unsigned dylib упадёт с 'code signature invalid'. Решения: (а) подписать dylib через codesign тем же Team ID, (б) встроить dylib в приложение через Xcode (Embed & Sign) и пересобрать IPA, (в) ставить через TrollStore.")
        } else {
            Logger.shared.log(.ok, tag: tag, "Момент 3/5 ✓ джейл — подпись не так критична")
        }

        // --- 4. dlopen ---
        let windowsBefore = OverlayHost.windowSnapshot()
        Logger.shared.log(.info, tag: tag, "Момент 4/5 · вызов dlopen('\(url.path)', RTLD_NOW|RTLD_GLOBAL)…")
        // Уже загружена?
        lock.lock()
        if loaded[url.path] != nil {
            lock.unlock()
            Logger.shared.log(.warn, tag: tag, "Момент 4/5 ⚠ уже загружена ранее — сначала Выгрузить, потом грузить новую версию (иначе iOS использует кэш).")
            return
        }
        lock.unlock()

        // Сбрасываем прошлую ошибку
        _ = dlerror()
        let handle: UnsafeMutableRawPointer? = url.path.withCString { cpath in
            dlopen(cpath, RTLD_NOW | RTLD_GLOBAL)
        }
        if let h = handle {
            lock.lock()
            loaded[url.path] = LoadedDylib(url: url, handle: h, loadedAt: Date())
            lock.unlock()
            Logger.shared.log(.ok, tag: tag, "Момент 4/5 ✓ dlopen ВЕРНУЛ ХЭНДЛ \(h). Библиотека в памяти.")
            DispatchQueue.main.async { NotificationCenter.default.post(name: .DylibLabLoadedListChanged, object: nil) }
            checkOptionalSymbols(handle: h, name: name)
            // --- 5. Оверлей ---
            waitForOverlay(name: name, windowsBefore: windowsBefore)
        } else {
            let rawErr: String
            if let e = dlerror() { rawErr = String(cString: e) } else { rawErr = "(dlerror пустой)" }
            Logger.shared.log(.err, tag: tag, "Момент 4/5 ✕ DLOPEN УПАЛ: \(rawErr)")
            explainDlerror(rawErr, fileName: name)
        }
    }

    func unload(url: URL) {
        lock.lock()
        guard let rec = loaded.removeValue(forKey: url.path) else {
            lock.unlock()
            Logger.shared.log(.warn, tag: "DLOPEN", "Выгрузка \(url.lastPathComponent): не была загружена")
            return
        }
        lock.unlock()
        dlclose(rec.handle)
        Logger.shared.log(.info, tag: "DLOPEN", "Выгружена \(url.lastPathComponent) (dlclose). Конструкторы не откатываются — для чистого теста перезапусти приложение.")
        DispatchQueue.main.async { NotificationCenter.default.post(name: .DylibLabLoadedListChanged, object: nil) }
    }

    func unloadAll() {
        for u in loadedURLs { unload(url: u) }
    }

    func autoloadFromDocuments() {
        let list = DylibStore.listCandidates().filter { $0.path.contains("Documents") }
        if list.isEmpty {
            Logger.shared.log(.info, tag: "AUTOLOAD", "Автозагрузка: в Documents/Dylibs пусто — закинь .dylib через Файлы или iTunes Sharing")
            return
        }
        Logger.shared.log(.info, tag: "AUTOLOAD", "Автозагрузка: найдено \(list.count), гружу по очереди…")
        for u in list { load(url: u, autoload: true) }
    }

    // MARK: - Объяснение ошибок

    private func explainDlerror(_ err: String, fileName: String) {
        let tag = "DLOPEN"
        let e = err.lowercased()
        if e.contains("code signature") || e.contains("code signing") || e.contains("invalid signature") {
            Logger.shared.log(.err, tag: tag, "Причина: НЕТ ПОДПИСИ / чужая подпись. iOS (без джейла) отклонила dylib. Что делать: 1) Подпиши dylib тем же сертификатом: codesign -f -s \"Apple Development: ...\" \(fileName) 2) Либо встрой через Xcode → Frameworks → Embed & Sign и пересобери IPA 3) Либо ставь через TrollStore.")
        } else if e.contains("no suitable image") {
            Logger.shared.log(.err, tag: tag, "Причина: NO SUITABLE IMAGE — обычно = нет arm64 среза ИЛИ нет подписи. Проверь выше строки Момент 2/5 и 3/5. Если arch ок — дело в подписи.")
        } else if e.contains("library not loaded") || e.contains("image not found") || e.contains("dependent") {
            Logger.shared.log(.err, tag: tag, "Причина: ЗАВИСИМОСТИ НЕ НАЙДЕНЫ — dylib ссылается на другой framework/dylib которого нет рядом. Решение: otool -L \(fileName) на Mac → доложи недостающие файлы рядом / в Frameworks, либо собери статически.")
        } else if e.contains("symbol not found") || e.contains("undefined symbol") {
            Logger.shared.log(.err, tag: tag, "Причина: НЕ НАЙДЕН СИМВОЛ — dylib собран под другую версию игры/SDK, не хватает функции. Решение: пересобери под актуальные хедеры, проверь что меню не ищет символы игры при загрузке (отложи поиск до появления игры).")
        } else if e.contains("mmap") || e.contains("wrong architecture") || e.contains("mach-o") {
            Logger.shared.log(.err, tag: tag, "Причина: БИТЫЙ MACH-O / не та платформа. Пересобери для iphoneos arm64 (не iphonesimulator, не macosx).")
        } else {
            Logger.shared.log(.err, tag: tag, "Причина: неизвестная (см. текст выше). Скопируй весь лог кнопкой «Копировать» и приложи к вопросу — там есть путь, arch и момент падения.")
        }
        Logger.shared.log(.info, tag: tag, "Следующий шаг: вкладка ЛОГИ → Копировать → отправь автору меню вместе с .dylib.")
    }

    private func checkOptionalSymbols(handle: UnsafeMutableRawPointer, name: String) {
        // Многие менюшки экспортируют C-функции — проверим популярные имена, purely для подсказок
        let probes = ["showMenu", "initMenu", "hack_init", "modmenu", "presentMenu"]
        var found: [String] = []
        for sym in probes {
            _ = dlerror()
            if dlsym(handle, sym) != nil { found.append(sym) }
        }
        if found.isEmpty {
            Logger.shared.log(.info, tag: "SYM", "\(name): известных entry-символов не найдено — нормально, меню может стартовать через constructor (__attribute__((constructor))). Ждём окно…")
        } else {
            let symList = found.joined(separator: ", ")
            Logger.shared.log(.ok, tag: "SYM", name + ": найдены символы: " + symList)
        }
    }

    private func waitForOverlay(name: String, windowsBefore: Set<String>) {
        Logger.shared.log(.info, tag: "OVERLAY", "Момент 5/5 · жду оверлей меню 2 сек (конструктор + UIWindow)…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let after = OverlayHost.windowSnapshot()
            let fresh = after.subtracting(windowsBefore)
            if fresh.isEmpty {
                Logger.shared.log(.warn, tag: "OVERLAY", "Момент 5/5 ⚠ новых UIWindow НЕ появилось. Это НЕ обязательно ошибка: меню может (а) рисоваться внутри существующего окна, (б) ждать тапа/шейка, (в) крашнуться молча — смотри краш-лог. Нажми «Тест оверлея» чтобы проверить что UIWindow поверх вообще работает.")
            } else {
                let freshList = fresh.joined(separator: ", ")
                Logger.shared.log(.ok, tag: "OVERLAY", "Момент 5/5. Меню создало окна: " + freshList)
            }
        }
    }
}
