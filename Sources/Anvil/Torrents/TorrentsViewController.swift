import UIKit
import os

final class TorrentsViewController: UIViewController {
    private let api: APIClient
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "torrents")

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var torrentsByHash: [String: Torrent] = [:]
    private let filterBar = FilterChipsView()
    private let statsBar = GlobalStatsBar()
    private let refreshControl = UIRefreshControl()
    private let emptyView = EmptyStateView()

    private var torrents: [Torrent] = []
    private var lastTransfer: TransferInfo?
    private var currentFilter: TorrentFilter = .all
    private var searchText: String = ""
    private var refreshTask: Task<Void, Never>?
    private var hasLoadedOnce = false
    private var currentSort: SortKey = SortKey.loadPersisted()
    private var sortReverse: Bool = SortKey.loadReverse()
    private var sortButton: UIBarButtonItem!

    enum SortKey: String, CaseIterable {
        case addedOn = "added_on"
        case name
        case size
        case progress
        case ratio
        case dlspeed
        case upspeed
        case eta
        case state
        case completionOn = "completion_on"

        var title: String {
            switch self {
            case .addedOn: return "Date added"
            case .name: return "Name"
            case .size: return "Size"
            case .progress: return "Progress"
            case .ratio: return "Ratio"
            case .dlspeed: return "Download speed"
            case .upspeed: return "Upload speed"
            case .eta: return "ETA"
            case .state: return "State"
            case .completionOn: return "Date completed"
            }
        }

        var symbol: String {
            switch self {
            case .addedOn: return "calendar.badge.clock"
            case .name: return "textformat.abc"
            case .size: return "internaldrive"
            case .progress: return "chart.bar.fill"
            case .ratio: return "scale.3d"
            case .dlspeed: return "arrow.down"
            case .upspeed: return "arrow.up"
            case .eta: return "hourglass"
            case .state: return "circle.grid.2x2"
            case .completionOn: return "checkmark.circle"
            }
        }

        private static let sortKeyDefault = "anvil_sort_key"
        private static let reverseKeyDefault = "anvil_sort_reverse"

        static func loadPersisted() -> SortKey {
            if let raw = UserDefaults.standard.string(forKey: sortKeyDefault), let key = SortKey(rawValue: raw) {
                return key
            }
            return .addedOn
        }

        static func loadReverse() -> Bool {
            if UserDefaults.standard.object(forKey: reverseKeyDefault) == nil { return true }
            return UserDefaults.standard.bool(forKey: reverseKeyDefault)
        }

        func persist() { UserDefaults.standard.set(rawValue, forKey: Self.sortKeyDefault) }
        static func persistReverse(_ value: Bool) { UserDefaults.standard.set(value, forKey: reverseKeyDefault) }
    }

    init(api: APIClient) {
        self.api = api
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Torrents"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let search = UISearchController(searchResultsController: nil)
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Filter torrents"
        search.searchResultsUpdater = self
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = true

        sortButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), menu: makeSortMenu())
        navigationItem.rightBarButtonItem = sortButton

        configureNavBarAppearance()

        filterBar.translatesAutoresizingMaskIntoConstraints = false
        filterBar.onSelect = { [weak self] filter in
            guard let self else { return }
            currentFilter = filter
            applySnapshot(animating: false)
        }
        view.addSubview(filterBar)

        statsBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsBar)

        let layout = makeLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)

        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        refreshControl.addAction(UIAction { [weak self] _ in Task { await self?.refresh(force: true) } }, for: .valueChanged)

        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: statsBar.topAnchor),

            statsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])

        configureDataSource()
    }

    private func configureNavBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.compactScrollEdgeAppearance = appearance
        filterBar.backgroundColor = .systemBackground
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

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] _, env in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.backgroundColor = .systemBackground
            config.separatorConfiguration.topSeparatorVisibility = .hidden
            config.separatorConfiguration.bottomSeparatorVisibility = .visible
            config.separatorConfiguration.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            config.leadingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                self?.makeLeadingSwipe(for: indexPath)
            }
            config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                self?.makeTrailingSwipe(for: indexPath)
            }
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
        }
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { [weak self] cell, _, hash in
            guard let torrent = self?.torrentsByHash[hash] else { return }
            cell.contentConfiguration = TorrentRowConfiguration(
                hash: torrent.hash,
                name: torrent.name,
                stateRaw: torrent.state,
                progress: torrent.progress,
                size: torrent.size,
                downloaded: torrent.downloaded,
                dlspeed: torrent.dlspeed,
                upspeed: torrent.upspeed,
                eta: torrent.eta,
                ratio: torrent.ratio,
                numSeeds: torrent.numSeeds,
                numLeechs: torrent.numLeechs
            )
            cell.accessories = [.disclosureIndicator()]
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(force: false)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refresh(force: Bool) async {
        do {
            let fetched: [Torrent] = try await api.request(.torrentsInfo(sort: currentSort.rawValue, reverse: sortReverse))
            try Task.checkCancellation()
            let info: TransferInfo = try await api.request(.transferInfo)
            try Task.checkCancellation()
            self.torrents = fetched
            self.torrentsByHash = Dictionary(uniqueKeysWithValues: fetched.map { ($0.hash, $0) })
            self.lastTransfer = info
            hasLoadedOnce = true
            applySnapshot(animating: false)
            refreshFilterCounts()
            navigationItem.prompt = nil
        } catch is CancellationError {
            return
        } catch {
            if !hasLoadedOnce {
                navigationItem.prompt = error.localizedDescription
            }
            log.error("Refresh failed: \(error)")
        }
        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
    }

    private func filteredTorrents() -> [Torrent] {
        let needle = searchText.lowercased()
        return torrents.filter { matches(filter: currentFilter, torrent: $0) }
            .filter { needle.isEmpty || $0.name.lowercased().contains(needle) }
    }

    private func matches(filter: TorrentFilter, torrent: Torrent) -> Bool {
        let state = TorrentState.parse(torrent.state)
        switch filter {
        case .all: return true
        case .downloading: return state.isDownloading
        case .seeding: return state.isSeeding
        case .completed: return torrent.progress >= 1.0
        case .stopped: return state.isStopped
        case .errored: return state.isErrored
        }
    }

    private func refreshFilterCounts() {
        var counts: [TorrentFilter: Int] = [:]
        for filter in TorrentFilter.allCases {
            counts[filter] = torrents.filter { matches(filter: filter, torrent: $0) }.count
        }
        filterBar.setCounts(counts)
    }

    private func applySnapshot(animating: Bool) {
        let items = filteredTorrents()
        let hashes = items.map(\.hash)
        var snap = NSDiffableDataSourceSnapshot<Int, String>()
        snap.appendSections([0])
        snap.appendItems(hashes, toSection: 0)
        snap.reconfigureItems(hashes)
        dataSource.apply(snap, animatingDifferences: animating)
        emptyView.isHidden = !items.isEmpty || !hasLoadedOnce
        emptyView.configure(filter: currentFilter, searchText: searchText)
        statsBar.update(transfer: lastTransfer, total: torrents.count, visible: items.count)
    }

    private func torrent(at indexPath: IndexPath) -> Torrent? {
        guard let hash = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return torrentsByHash[hash]
    }

    private func makeLeadingSwipe(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let torrent = torrent(at: indexPath) else { return nil }
        let state = TorrentState.parse(torrent.state)
        let title = state.isStopped ? "Start" : "Stop"
        let symbol = state.isStopped ? "play.fill" : "pause.fill"
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            Task { await self?.toggle(torrent: torrent); completion(true) }
        }
        action.image = UIImage(systemName: symbol)
        action.backgroundColor = state.isStopped ? Theme.uploadColor : Theme.checkingColor
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func makeTrailingSwipe(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let torrent = torrent(at: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.confirmDelete(torrent: torrent)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash.fill")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    private func toggle(torrent: Torrent) async {
        let state = TorrentState.parse(torrent.state)
        do {
            if state.isStopped {
                try await api.requestVoid(.start(hashes: [torrent.hash]))
            } else {
                try await api.requestVoid(.stop(hashes: [torrent.hash]))
            }
            await refresh(force: true)
        } catch {
            log.error("Toggle failed: \(error)")
            presentError(error)
        }
    }

    private func confirmDelete(torrent: Torrent) {
        let alert = UIAlertController(title: "Delete torrent?", message: torrent.name, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove from list", style: .default) { [weak self] _ in
            self?.delete(torrent: torrent, withFiles: false)
        })
        alert.addAction(UIAlertAction(title: "Remove and delete files", style: .destructive) { [weak self] _ in
            self?.delete(torrent: torrent, withFiles: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func delete(torrent: Torrent, withFiles: Bool) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await api.requestVoid(.delete(hashes: [torrent.hash], deleteFiles: withFiles))
                self.torrents.removeAll { $0.hash == torrent.hash }
                self.torrentsByHash.removeValue(forKey: torrent.hash)
                applySnapshot(animating: true)
                refreshFilterCounts()
            } catch {
                log.error("Delete failed: \(error)")
                presentError(error)
            }
        }
    }

    private func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func makeSortMenu() -> UIMenu {
        let fieldActions = SortKey.allCases.map { key in
            UIAction(
                title: key.title,
                image: UIImage(systemName: key.symbol),
                state: key == currentSort ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                currentSort = key
                key.persist()
                sortButton.menu = makeSortMenu()
                Task { await self.refresh(force: true) }
            }
        }
        let fieldsMenu = UIMenu(title: "Sort by", options: .displayInline, children: fieldActions)

        let directionAction = UIAction(
            title: sortReverse ? "Descending" : "Ascending",
            image: UIImage(systemName: sortReverse ? "arrow.down" : "arrow.up"),
            state: sortReverse ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            sortReverse.toggle()
            SortKey.persistReverse(sortReverse)
            sortButton.menu = makeSortMenu()
            Task { await self.refresh(force: true) }
        }
        let directionMenu = UIMenu(title: "", options: .displayInline, children: [directionAction])

        return UIMenu(title: "", children: [fieldsMenu, directionMenu])
    }
}


extension TorrentsViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        cv.deselectItem(at: indexPath, animated: true)
        guard let torrent = torrent(at: indexPath) else { return }
        let detail = TorrentDetailViewController(api: api, torrent: torrent)
        navigationController?.pushViewController(detail, animated: true)
    }

    func collectionView(_ cv: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let torrent = torrent(at: indexPath) else { return nil }
        let state = TorrentState.parse(torrent.state)
        return UIContextMenuConfiguration(identifier: torrent.hash as NSString, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let toggle = UIAction(
                title: state.isStopped ? "Start" : "Stop",
                image: UIImage(systemName: state.isStopped ? "play.fill" : "pause.fill")
            ) { [weak self] _ in Task { await self?.toggle(torrent: torrent) } }
            let recheck = UIAction(title: "Force recheck", image: UIImage(systemName: "checkmark.shield")) { [weak self] _ in
                Task { try? await self?.api.requestVoid(.recheck(hashes: [torrent.hash])) }
            }
            let reannounce = UIAction(title: "Reannounce", image: UIImage(systemName: "antenna.radiowaves.left.and.right")) { [weak self] _ in
                Task { try? await self?.api.requestVoid(.reannounce(hashes: [torrent.hash])) }
            }
            let copyMagnet = UIAction(title: "Copy magnet link", image: UIImage(systemName: "link")) { _ in
                UIPasteboard.general.string = torrent.magnetUri
            }
            let delete = UIAction(title: "Delete…", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDelete(torrent: torrent)
            }
            return UIMenu(children: [toggle, recheck, reannounce, copyMagnet, delete])
        }
    }
}

extension TorrentsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text ?? ""
        applySnapshot(animating: false)
    }
}

final class EmptyStateView: UIView {
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
        icon.tintColor = .tertiaryLabel
        icon.contentMode = .scaleAspectFit

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center

        detailLabel.font = .systemFont(ofSize: 14, weight: .regular)
        detailLabel.textColor = .tertiaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(filter: TorrentFilter, searchText: String) {
        if !searchText.isEmpty {
            icon.image = UIImage(systemName: "magnifyingglass")
            titleLabel.text = "No matches"
            detailLabel.text = "Nothing matches \"\(searchText)\""
        } else {
            icon.image = UIImage(systemName: filter.symbol)
            switch filter {
            case .all:
                titleLabel.text = "No torrents"
                detailLabel.text = "Add one from the Add tab to get started."
            case .downloading:
                titleLabel.text = "Nothing downloading"
                detailLabel.text = "All downloads are complete or paused."
            case .seeding:
                titleLabel.text = "Nothing seeding"
                detailLabel.text = "No active uploads right now."
            case .completed:
                titleLabel.text = "No completed torrents"
                detailLabel.text = "Finished downloads will appear here."
            case .stopped:
                titleLabel.text = "No paused torrents"
                detailLabel.text = "Everything is running."
            case .errored:
                titleLabel.text = "No errors"
                detailLabel.text = "Nothing went wrong. Yet."
            }
        }
    }
}
