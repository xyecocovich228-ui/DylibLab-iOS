import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        window.backgroundColor = .black
        self.window = window
        window.makeKeyAndVisible()

        Logger.shared.log(.ok, tag: "UI", "WindowScene готов · \(Int(windowScene.screen.bounds.width))x\(Int(windowScene.screen.bounds.height)) · интерфейс: landscape")

        // Автозагрузка dylib если включена — с задержкой чтобы UI успел подняться
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if UserDefaults.standard.bool(forKey: "autload_on_start") {
                DylibLoader.shared.autoloadFromDocuments()
            }
        }
    }
}
