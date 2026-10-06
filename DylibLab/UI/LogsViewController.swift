import UIKit

/// Вкладка ЛОГИ: живой лог, фильтры, копирование одной кнопкой.
class LogsViewController: UIViewController {
    private let textView = UITextView()
    private var activeLevels: Set<LogLevel> = []
    private var followTail = true
    private var filterButtons: [LogLevel: UIButton] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Логи · что сломалось и почему"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        setupUI()
        NotificationCenter.default.addObserver(forName: .DylibLabLogAdded, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let e = note.object as? LogEntry else { return }
            self.append(entry: e)
        }
        reloadAll()
    }

    private func setupUI() {
        // Верхняя панель фильтров
        let filterRow = UIStackView()
        filterRow.axis = .horizontal
        filterRow.spacing = 6
        filterRow.distribution = .fillEqually
        filterRow.translatesAutoresizingMaskIntoConstraints = false
        for (idx, lvl) in LogLevel.allCases.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(lvl.rawValue, for: .normal)
            b.titleLabel?.font = .boldSystemFont(ofSize: 13)
            b.layer.cornerRadius = 8
            b.layer.borderWidth = 1
            b.layer.borderColor = color(for: lvl).cgColor
            b.setTitleColor(color(for: lvl), for: .normal)
            b.tag = idx
            b.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
            filterButtons[lvl] = b
            filterRow.addArrangedSubview(b)
        }

        // Кнопки действий
        let actionRow = UIStackView()
        actionRow.axis = .horizontal
        actionRow.spacing = 6
        actionRow.distribution = .fillEqually
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        let copyB = actionButton("⎘ Копировать", color: .systemGreen, action: #selector(copyTapped))
        let shareB = actionButton("⇪ Поделиться", color: .systemBlue, action: #selector(shareTapped))
        let clearB = actionButton("🗑 Очистить", color: .systemRed, action: #selector(clearTapped))
        // follow switch
        let followB = actionButton("⬇ Следить: вкл", color: .darkGray, action: #selector(followTapped))
        followB.tag = 999
        actionRow.addArrangedSubview(copyB)
        actionRow.addArrangedSubview(shareB)
        actionRow.addArrangedSubview(clearB)
        actionRow.addArrangedSubview(followB)

        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .black
        textView.textColor = .lightGray
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.cornerRadius = 10

        view.addSubview(filterRow)
        view.addSubview(actionRow)
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            filterRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            filterRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            actionRow.topAnchor.constraint(equalTo: filterRow.bottomAnchor, constant: 6),
            actionRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            actionRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.topAnchor.constraint(equalTo: actionRow.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func actionButton(_ title: String, color: UIColor, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.backgroundColor = color
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 14)
        b.layer.cornerRadius = 8
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func color(for lvl: LogLevel) -> UIColor {
        switch lvl {
        case .info: return .lightGray
        case .ok: return .systemGreen
        case .warn: return .systemYellow
        case .err: return .systemRed
        }
    }

    @objc private func filterTapped(_ sender: UIButton) {
        let all = LogLevel.allCases
        guard sender.tag >= 0 && sender.tag < all.count else { return }
        let lvl = all[sender.tag]
        if activeLevels.contains(lvl) {
            activeLevels.remove(lvl)
            sender.backgroundColor = .clear
        } else {
            activeLevels.insert(lvl)
            sender.backgroundColor = color(for: lvl).withAlphaComponent(0.25)
        }
        reloadAll()
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = Logger.shared.fullText(levels: activeLevels)
        Logger.shared.log(.ok, tag: "LOG", "Лог скопирован в буфер (\(activeLevels.isEmpty ? "все уровни" : activeLevels.map { $0.rawValue }.joined(separator: ",")))")
    }

    @objc private func shareTapped() {
        let text = Logger.shared.fullText(levels: activeLevels)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("dyliblab-log.txt")
        try? text.write(to: tmp, atomically: true, encoding: .utf8)
        let vc = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        // iPad popover
        vc.popoverPresentationController?.sourceView = view
        vc.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 60, width: 0, height: 0)
        present(vc, animated: true)
    }

    @objc private func clearTapped() {
        Logger.shared.clear()
        reloadAll()
    }

    @objc private func followTapped(_ sender: UIButton) {
        followTail.toggle()
        sender.setTitle(followTail ? "⬇ Следить: вкл" : "⬇ Следить: выкл", for: .normal)
    }

    private func reloadAll() {
        let entries = Logger.shared.filtered(activeLevels)
        let attr = NSMutableAttributedString()
        for e in entries {
            attr.append(coloredLine(e))
        }
        textView.attributedText = attr
        scrollToBottom()
    }

    private func append(entry: LogEntry) {
        if !activeLevels.isEmpty && !activeLevels.contains(entry.level) { return }
        let attr = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        attr.append(coloredLine(entry))
        // Обрезаем текст чтобы не сожрать память
        if attr.length > 500_000 {
            attr.deleteCharacters(in: NSRange(location: 0, length: 100_000))
        }
        textView.attributedText = attr
        if followTail { scrollToBottom() }
    }

    private func coloredLine(_ e: LogEntry) -> NSAttributedString {
        let s = e.line() + "\n"
        return NSAttributedString(string: s, attributes: [
            .foregroundColor: color(for: e.level),
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        ])
    }

    private func scrollToBottom() {
        let len = textView.attributedText?.length ?? 0
        guard len > 0 else { return }
        textView.scrollRangeToVisible(NSRange(location: len - 1, length: 1))
    }
}
