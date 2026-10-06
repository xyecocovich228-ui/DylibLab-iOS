import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Лок: только горизонталь для всего приложения
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.shared.log(.info, tag: "APP", "DylibLab запущен · \(DeviceInfo.summary())")
        DylibStore.ensureDirectories()
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration",
                                    sessionRole: connectingSceneSession.role)
    }
}
