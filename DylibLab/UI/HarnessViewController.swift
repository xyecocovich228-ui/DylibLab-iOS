import UIKit
import UniformTypeIdentifiers

/// Корневой TabBar — 4 вкладки стенда. Всё в landscape.
class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let harness = UINavigationController(rootViewController: HarnessViewController())
        harness.tabBarItem = UITabBarItem(title: "Стенд", image: UIImage(systemName: "flask.fill"), tag: 0)
        let logs = UINavigationController(rootViewController: LogsViewController())
        logs.tabBarItem = UITabBarItem(title: "Логи", image: UIImage(systemName: "doc.text.fill"), tag: 1)
        let files = UINavigationController(rootViewController: FilesViewController())
        files.tabBarItem = UITabBarItem(title: "Файлы", image: UIImage(systemName: "folder.fill"), tag: 2)
        let help = UINavigationController(rootViewController: HelpViewController())
        help.tabBarItem = UITabBarItem(title: "Хелп", image: UIImage(systemName: "questionmark.circle.fill"), tag: 3)
        viewControllers = [harness, logs, files, help]
        tabBar.tintColor = .systemGreen
        tabBar.barTintColor = .black
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.landscapeLeft, .landscapeRight]
    }
}

// MARK: - Вкладка 1: Стенд

class HarnessViewController: UIViewController {
    private let statusLabel = UILabel()
    private let compatLabel = UILabel()
    private let loadedLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DylibLab · Стенд"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        setupUI()
        refresh()
        NotificationCenter.default.addObserver(forName: .DylibLabLoadedListChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { [.landscapeLeft, .landscapeRight] }

    private func setupUI() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        statusLabel.numberOfLines = 0
        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .systemGreen
        stack.addArrangedSubview(card(title: "СТАТУС", body: statusLabel))

        compatLabel.numberOfLines = 0
        compatLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        compatLabel.textColor = .lightGray
        stack.addArrangedSubview(card(title: "СОВМЕСТИМОСТЬ", body: compatLabel))

        loadedLabel.numberOfLines = 0
        loadedLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        loadedLabel.textColor = .systemYellow
        stack.addArrangedSubview(card(title: "ЗАГРУЖЕННЫЕ DYLIB", body: loadedLabel))

        // Кнопки — два ряда
        let row1 = UIStackView()
        row1.axis = .horizontal; row1.spacing = 8; row1.distribution = .fillEqually
        row1.addArrangedSubview(makeButton("＋ Импорт .dylib", color: .systemGreen, action: #selector(importTapped)))
        row1.addArrangedSubview(makeButton("▶ Загрузить все", color: .systemBlue, action: #selector(loadAllTapped)))
        row1.addArrangedSubview(makeButton("⏏ Выгрузить все", color: .systemOrange, action: #selector(unloadTapped)))
        stack.addArrangedSubview(row1)

        let row2 = UIStackView()
        row2.axis = .horizontal; row2.spacing = 8; row2.distribution = .fillEqually
        row2.addArrangedSubview(makeButton("◉ Тест оверлея", color: .systemRed, action: #selector(overlayTapped)))
        row2.addArrangedSubview(makeButton("✕ Скрыть оверлей", color: .darkGray, action: #selector(hideOverlayTapped)))
        row2.addArrangedSubview(makeButton("⎘ Копировать лог", color: .systemTeal, action: #selector(copyLogTapped)))
        stack.addArrangedSubview(row2)

        let row3 = UIStackView()
        row3.axis = .horizontal; row3.spacing = 8; row3.distribution = .fillEqually
        let auto = UISwitch()
        auto.isOn = UserDefaults.standard.bool(forKey: "autload_on_start")
        auto.addTarget(self, action: #selector(autoSwitch(_:)), for: .valueChanged)
        let autoLabel = UILabel()
        autoLabel.text = "Автозагрузка при старте"
        autoLabel.textColor = .white
        autoLabel.font = .systemFont(ofSize: 14)
        let autoRow = UIStackView(arrangedSubviews: [autoLabel, auto])
        autoRow.spacing = 8
        row3.addArrangedSubview(autoRow)
        row3.addArrangedSubview(makeButton("↻ Обновить", color: .systemGray, action: #selector(refreshTapped)))
        row3.addArrangedSubview(makeButton("☰ Окна: в лог", color: .systemPurple, action: #selector(dumpWindowsTapped)))
        stack.addArrangedSubview(row3)
    }

    private func card(title: String, body: UILabel) -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.12, alpha: 1)
        v.layer.cornerRadius = 10
        let t = UILabel()
        t.text = title
        t.font = .boldSystemFont(ofSize: 12)
        t.textColor = .systemGray
        t.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(t); v.addSubview(body)
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            t.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            t.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            body.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 4),
            body.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            body.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            body.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -8)
        ])
        return v
    }

    private func makeButton(_ title: String, color: UIColor, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.backgroundColor = color
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 15)
        b.layer.cornerRadius = 10
        b.heightAnchor.constraint(equalToConstant: 48).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func refresh() {
        statusLabel.text = DeviceInfo.summary()
        compatLabel.text = OverlayHost.compatibilityReport()
        let loaded = DylibLoader.shared.loadedURLs
        loadedLabel.text = loaded.isEmpty ? "(пусто — импортируй .dylib и жми Загрузить)" : loaded.map { "● \($0.lastPathComponent)" }.joined(separator: "\n")
    }

    @objc private func importTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
        Logger.shared.log(.info, tag: "UI", "Открыт импорт файлов — выбери .dylib (копируется в Documents/Dylibs)")
    }

    @objc private func loadAllTapped() {
        let cands = DylibStore.listCandidates().filter { $0.path.contains("Documents") }
        if cands.isEmpty {
            Logger.shared.log(.warn, tag: "UI", "Загрузить все: в Documents/Dylibs ничего нет. Сначала Импорт или закинь через Files/AirDrop.")
            return
        }
        for u in cands { DylibLoader.shared.load(url: u) }
        refresh()
    }

    @objc private func unloadTapped() {
        DylibLoader.shared.unloadAll()
        refresh()
    }

    @objc private func overlayTapped() {
        OverlayHost.showTestOverlay()
    }
    @objc private func hideOverlayTapped() {
        OverlayHost.hideTestOverlay()
    }

    @objc private func copyLogTapped() {
        UIPasteboard.general.string = Logger.shared.fullText()
        Logger.shared.log(.ok, tag: "UI", "Лог скопирован в буфер обмена (\(Logger.shared.allEntries().count) строк)")
        toast("Лог скопирован")
    }

    @objc private func refreshTapped() { refresh() }

    @objc private func dumpWindowsTapped() {
        Logger.shared.log(.info, tag: "OVERLAY", "Дамп окон:\n\(OverlayHost.describeWindows())")
    }

    @objc private func autoSwitch(_ s: UISwitch) {
        UserDefaults.standard.set(s.isOn, forKey: "autload_on_start")
        Logger.shared.log(.info, tag: "UI", "Автозагрузка \(s.isOn ? "ВКЛ" : "ВЫКЛ")")
    }

    private func toast(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        present(a, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { a.dismiss(animated: true) }
    }
}

extension HarnessViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        DylibStore.ensureDirectories()
        for src in urls {
            let dst = DylibStore.dylibsDir().appendingPathComponent(src.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dst.path) {
                    try FileManager.default.removeItem(at: dst)
                }
                // asCopy=true уже даёт копию в inbox — копируем к себе
                let needStop = src.startAccessingSecurityScopedResource()
                defer { if needStop { src.stopAccessingSecurityScopedResource() } }
                try FileManager.default.copyItem(at: src, to: dst)
                Logger.shared.log(.ok, tag: "STORE", "Импортирован \(src.lastPathComponent) → Dylibs (\( (try? FileManager.default.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? 0) байт)")
                // Сразу пробуем грузить — так быстрее тестировать
                DylibLoader.shared.load(url: dst)
            } catch {
                Logger.shared.log(.err, tag: "STORE", "Импорт \(src.lastPathComponent) ✕: \(error.localizedDescription)")
            }
        }
        refresh()
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Logger.shared.log(.info, tag: "UI", "Импорт отменён")
    }
}
