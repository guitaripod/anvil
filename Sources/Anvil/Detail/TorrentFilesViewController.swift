import UIKit
import os

final class TorrentFilesViewController: UIViewController {
    private let api: APIClient
    private let torrentHash: String
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "files")

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, TorrentFile>!
    private var files: [TorrentFile] = []
    private var refreshTask: Task<Void, Never>?

    init(api: APIClient, hash: String, name: String) {
        self.api = api
        self.torrentHash = hash
        super.init(nibName: nil, bundle: nil)
        title = "Files"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        var listConfig = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfig.headerMode = .none
        let layout = UICollectionViewCompositionalLayout.list(using: listConfig)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, TorrentFile> { cell, _, file in
            var content = cell.defaultContentConfiguration()
            content.text = (file.name as NSString).lastPathComponent
            content.textProperties.font = .systemFont(ofSize: 15, weight: .medium)
            content.textProperties.numberOfLines = 2
            content.secondaryText = Self.detailText(for: file)
            content.secondaryTextProperties.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = UIImage(systemName: file.progress >= 1.0 ? "checkmark.circle.fill" : "doc")
            content.imageProperties.tintColor = file.progress >= 1.0 ? .systemGreen : Theme.accent
            content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAutoRefresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func refresh() async {
        do {
            files = try await api.request(.torrentFiles(hash: torrentHash))
            try Task.checkCancellation()
            applySnapshot()
        } catch is CancellationError {
            return
        } catch {
            log.error("Files refresh failed: \(error)")
        }
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, TorrentFile>()
        snap.appendSections([0])
        snap.appendItems(files, toSection: 0)
        dataSource.apply(snap, animatingDifferences: false)
    }
}

extension TorrentFilesViewController {
    static func detailText(for file: TorrentFile) -> String {
        var parts: [String] = [Formatters.percent(file.progress), Formatters.byteCount(file.size)]
        switch file.priority {
        case 0: parts.append("Skip")
        case 6: parts.append("High")
        case 7: parts.append("Max")
        default: break
        }
        return parts.joined(separator: "  ·  ")
    }
}
