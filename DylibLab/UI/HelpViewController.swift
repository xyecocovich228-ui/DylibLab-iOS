import UIKit

/// Вкладка ХЕЛП: как собирать менюшки, таблица ошибок, шаблон dylib.
class HelpViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Хелп · как тестить меню"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)

        let tv = UITextView()
        tv.isEditable = false
        tv.backgroundColor = .black
        tv.textColor = .white
        tv.font = .systemFont(ofSize: 14)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.layer.cornerRadius = 10
        view.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tv.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            tv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
        tv.attributedText = helpAttributed()
    }

    private func helpAttributed() -> NSAttributedString {
        let raw = """
        DYLYBLAB — СТЕНД ДЛЯ ТЕСТА .DYLIB МЕНЮШЕК
        ========================================
        Зачем: не вшивать каждую версию меню в игру вслепую,
        а сначала прогнать dylib здесь и увидеть в логе ЧТО / ПОЧЕМУ / НА КАКОМ МОМЕНТЕ упало.

        КАК ТЕСТИРОВАТЬ (3 шага):
        1. Стенд → Импорт .dylib → файл копируется в Documents/Dylibs.
        2. Автоматически вызывается dlopen. Смотри вкладку Логи:
           Момент 1/5 файл → 2/5 arch → 3/5 подпись → 4/5 dlopen → 5/5 оверлей.
        3. Если dlopen ✓ но меню не видно → жми «Тест оверлея».
           Если красная кнопка таскается — UIWindow работает, копай своё меню
           (hidden / frame / windowLevel / инициализация на главном потоке).

        ТАБЛИЦА ОШИБОК DLOPEN:
        • code signature invalid → нет подписи. Подпиши тем же сертом что и IPA:
          codesign -f -s "Apple Development: xxx" menu.dylib
          или встрой через Xcode → Embed & Sign и пересобери IPA.
        • no suitable image → нет arm64 среза или нет подписи. Смотри Момент 2/5.
        • library not loaded / image not found → dylib тянет зависимости.
          На Mac: otool -L menu.dylib → доложи их рядом.
        • symbol not found → меню ищет символы игры которых нет в стенде.
          Это ОК для стенда: главное что dlopen прошёл. Отложи поиск символов
          до запуска игры (lazy), а не в constructor.
        • constructor крашит → меню падает при загрузке. Ошибка будет в краш-логе
          iOS (Настройки → Конфиденциальность → Аналитика). Стенд залогирует
          «dlopen упал», а детали — в системном краше.

        КАК СОБРАТЬ ТЕСТОВУЮ .DYLIB (пример в папке DylibTemplate):
        • Минимальный шаблон MenuTemplate.m создаёт красное окно с кнопкой.
          Сборка на Mac:
          xcrun -sdk iphoneos clang -arch arm64 -dynamiclib \\
            -framework UIKit -framework Foundation \\
            MenuTemplate.m -o menu.dylib
          Подпись:
          codesign -f -s "Apple Development: ..." menu.dylib
        • Затем AirDrop / Files → открыть в DylibLab → Импорт.

        ФИШКИ СТЕНДА:
        • Логи с меткой времени до миллисекунд, уровни INFO/OK/WARN/ERR.
        • Копирование лога одной кнопкой (Стенд и Логи).
        • Проверка Mach-O до dlopen: сразу видно x86_64 вместо arm64.
        • Детект новых UIWindow после загрузки — видно создало ли меню окно.
        • Тестовый оверлей с драгом — проверка тачей поверх.
        • File Sharing включён: можно кидать dylib через iTunes/Finder.
        • Только landscape: стенд заставляет меню работать горизонтально.

        СОВЕТЫ АВТОРАМ МЕНЮ:
        • Все UI-работы — на main thread (dispatch_async main).
        • Окно: UIWindow(windowScene:) + windowLevel = .alert + 1, isHidden = NO.
        • Не блокируй constructor: только dispatch_after / async, иначе watchdog.
        • Проверяй frame в landscape: width > height.
        • Логируй в NSLog — они тоже попадут в консоль рядом с логом стенда.

        \(DeviceInfo.detailed())
        """
        return NSAttributedString(string: raw, attributes: [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ])
    }
}
