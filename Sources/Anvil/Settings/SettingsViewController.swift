import UIKit
import os

final class SettingsViewController: UIViewController {
    private let api: APIClient
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Row>!
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "settings")

    private enum Section: Hashable { case server, app, danger }

    private struct Row: Hashable {
        let title: String
        let value: String?
        let symbol: String
        let tint: UIColor?
        let action: Identifier?

        enum Identifier: String, Hashable { case version, logout, copyURL, freeSpace, dhtNodes }
    }

    init(api: APIClient) {
        self.api = api
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        var listConfig = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfig.headerMode = .none
        let layout = UICollectionViewCompositionalLayout.list(using: listConfig)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Row> { cell, _, row in
            var content = cell.defaultContentConfiguration()
            content.text = row.title
            content.secondaryText = row.value
            content.image = UIImage(systemName: row.symbol)
            content.imageProperties.tintColor = row.tint ?? Theme.accent
            cell.contentConfiguration = content
            cell.accessories = row.action == nil ? [] : [.disclosureIndicator()]
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, row in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: row)
        }

        applyBaseSnapshot()
        Task { await loadAppInfo() }
    }

    private func applyBaseSnapshot(version: String? = nil, freeSpace: Int64? = nil, dhtNodes: Int? = nil) {
        var snap = NSDiffableDataSourceSnapshot<Section, Row>()
        snap.appendSections([.server, .app, .danger])
        snap.appendItems([
            Row(title: api.session.baseURL.host ?? "—", value: api.session.baseURL.absoluteString, symbol: "globe", tint: Theme.accent, action: .copyURL),
            Row(title: "Username", value: api.session.username, symbol: "person.fill", tint: Theme.accent, action: nil),
        ], toSection: .server)
        snap.appendItems([
            Row(title: "qBittorrent", value: version ?? "—", symbol: "shippingbox.fill", tint: .systemBlue, action: nil),
            Row(title: "Free space", value: freeSpace.map(Formatters.byteCount) ?? "—", symbol: "internaldrive", tint: .systemGreen, action: nil),
            Row(title: "DHT nodes", value: dhtNodes.map(String.init) ?? "—", symbol: "point.3.connected.trianglepath.dotted", tint: .systemPurple, action: nil),
        ], toSection: .app)
        snap.appendItems([
            Row(title: "Sign out", value: nil, symbol: "rectangle.portrait.and.arrow.right", tint: .systemRed, action: .logout),
        ], toSection: .danger)
        dataSource.apply(snap, animatingDifferences: false)
    }

    private func loadAppInfo() async {
        async let version: String? = try? await api.requestString(.version)
        do {
            let info: TransferInfo = try await api.request(.transferInfo)
            let v = await version
            applyBaseSnapshot(version: v?.trimmingCharacters(in: .whitespacesAndNewlines), freeSpace: nil, dhtNodes: info.dhtNodes)
        } catch {
            log.error("Loading app info failed: \(error)")
        }
    }
}

extension SettingsViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        cv.deselectItem(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath), let action = row.action else { return }
        switch action {
        case .logout:
            confirmSignOut()
        case .copyURL:
            UIPasteboard.general.string = api.session.baseURL.absoluteString
            let toast = ToastView(text: "URL copied", symbol: "checkmark.circle.fill")
            toast.show(in: view)
        default:
            break
        }
    }

    private func confirmSignOut() {
        let alert = UIAlertController(title: "Sign out?", message: "You'll need to re-enter your server credentials.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign out", style: .destructive) { [weak self] _ in
            self?.signOut()
        })
        present(alert, animated: true)
    }

    private func signOut() {
        ServerBootstrap.clear()
        guard let scene = view.window?.windowScene?.delegate as? SceneDelegate else { return }
        scene.reconfigureRoot()
    }
}
