import UIKit

/// Вкладка ФАЙЛЫ: что лежит в Documents/Dylibs, размер, arch, удалить, загрузить.
class FilesViewController: UIViewController {
    private let table = UITableView()
    private var files: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Файлы · Documents/Dylibs"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload))
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        // NOTE: не регистрируем класс — ячейки создаём в .subtitle стиле вручную
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        reload()
    }

    @objc private func reload() {
        DylibStore.ensureDirectories()
        let fm = FileManager.default
        let dir = DylibStore.dylibsDir()
        files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        files.sort { $0.lastPathComponent < $1.lastPathComponent }
        table.reloadData()
        Logger.shared.log(.info, tag: "STORE", "Файлы: в Dylibs \(files.count) шт · путь \(dir.path)")
    }
}

extension FilesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        files.isEmpty ? 1 : files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.backgroundColor = UIColor(white: 0.1, alpha: 1)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = .lightGray
        if files.isEmpty {
            cell.textLabel?.text = "(пусто) — нажми Стенд → Импорт .dylib"
            cell.textLabel?.font = .systemFont(ofSize: 14)
            return cell
        }
        let url = files[indexPath.row]
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        var arch = "?"
        switch MachoInspector.inspect(url: url) {
        case .success(let info): arch = info.archs.joined(separator: ",")
        case .failure(let e): arch = "не Mach-O: \(e.localizedDescription)"
        }
        cell.textLabel?.text = url.lastPathComponent
        cell.textLabel?.font = .boldSystemFont(ofSize: 15)
        cell.detailTextLabel?.text = "\(size) байт · \(arch)"
        // iOS 14+ subtitle style: используем detail через subtitle — пересоздадим стиль
        cell.textLabel?.numberOfLines = 1
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !files.isEmpty else { return }
        let url = files[indexPath.row]
        let sheet = UIAlertController(title: url.lastPathComponent, message: detailMessage(for: url), preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "▶ Загрузить (dlopen)", style: .default, handler: { _ in
            DylibLoader.shared.load(url: url)
        }))
        sheet.addAction(UIAlertAction(title: "⏏ Выгрузить", style: .default, handler: { _ in
            DylibLoader.shared.unload(url: url)
        }))
        sheet.addAction(UIAlertAction(title: "⎘ Скопировать инфо в буфер", style: .default, handler: { _ in
            UIPasteboard.general.string = self.detailMessage(for: url)
        }))
        sheet.addAction(UIAlertAction(title: "🗑 Удалить", style: .destructive, handler: { _ in
            do {
                try FileManager.default.removeItem(at: url)
                Logger.shared.log(.info, tag: "STORE", "Удалён \(url.lastPathComponent)")
                self.reload()
            } catch {
                Logger.shared.log(.err, tag: "STORE", "Удалить ✕: \(error.localizedDescription)")
            }
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(sheet, animated: true)
    }

    private func detailMessage(for url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        var extra = ""
        switch MachoInspector.inspect(url: url) {
        case .success(let info): extra = info.rawDescription
        case .failure(let e): extra = "НЕ Mach-O: \(e.localizedDescription)"
        }
        let loaded = DylibLoader.shared.loadedURLs.contains(where: { $0.path == url.path }) ? "загружена ✓" : "не загружена"
        return "Путь: \(url.path)\nРазмер: \(size)\n\(extra)\nСтатус: \(loaded)"
    }
}
