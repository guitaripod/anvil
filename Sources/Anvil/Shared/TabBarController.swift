import UIKit

final class TabBarController: UITabBarController {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = Theme.accent

        let torrents = UINavigationController(rootViewController: TorrentsViewController(api: api))
        torrents.tabBarItem = UITabBarItem(
            title: "Torrents",
            image: UIImage(systemName: "tray.full"),
            selectedImage: UIImage(systemName: "tray.full.fill")
        )

        let add = UINavigationController(rootViewController: AddTorrentViewController(api: api))
        add.tabBarItem = UITabBarItem(
            title: "Add",
            image: UIImage(systemName: "plus.circle"),
            selectedImage: UIImage(systemName: "plus.circle.fill")
        )

        let settings = UINavigationController(rootViewController: SettingsViewController(api: api))
        settings.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        viewControllers = [torrents, add, settings]
    }
}
