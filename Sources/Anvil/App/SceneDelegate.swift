import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.accent
        self.window = window
        window.makeKeyAndVisible()

        if let session = ServerBootstrap.session() {
            showMainApp(session: session)
        } else {
            showServerSetup()
        }
    }

    func reconfigureRoot() {
        if let session = ServerBootstrap.session() {
            showMainApp(session: session)
        } else {
            showServerSetup()
        }
    }

    private func showMainApp(session: ServerSession) {
        let api = APIClient(session: session)
        let tabBar = TabBarController(api: api)
        setRoot(tabBar)
    }

    private func showServerSetup() {
        let setup = ServerSetupViewController()
        setup.onConnected = { [weak self] api in
            guard let self else { return }
            setRoot(TabBarController(api: api))
        }
        setRoot(UINavigationController(rootViewController: setup))
    }

    private func setRoot(_ vc: UIViewController) {
        guard let window else { return }
        if window.rootViewController == nil {
            window.rootViewController = vc
        } else {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = vc
            }
        }
    }
}
