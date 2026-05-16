import UIKit
import os

final class TorrentTrackersViewController: UIViewController {
    private let api: APIClient
    private let torrentHash: String
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "trackers")

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, TrackerItem>!
    private var trackers: [TrackerItem] = []
    private var refreshTask: Task<Void, Never>?

    private struct TrackerItem: Hashable {
        let id: String
        let tracker: Tracker
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: TrackerItem, rhs: TrackerItem) -> Bool { lhs.id == rhs.id }
    }

    init(api: APIClient, hash: String, name: String) {
        self.api = api
        self.torrentHash = hash
        super.init(nibName: nil, bundle: nil)
        title = "Trackers"
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

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, TrackerItem> { cell, _, item in
            cell.contentConfiguration = TrackerRowConfiguration(tracker: item.tracker)
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
            let raw: [Tracker] = try await api.request(.torrentTrackers(hash: torrentHash))
            try Task.checkCancellation()
            trackers = raw.map { TrackerItem(id: $0.url, tracker: $0) }
            applySnapshot()
        } catch is CancellationError {
            return
        } catch {
            log.error("Trackers refresh failed: \(error)")
        }
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, TrackerItem>()
        snap.appendSections([0])
        snap.appendItems(trackers, toSection: 0)
        dataSource.apply(snap, animatingDifferences: false)
    }
}

struct TrackerRowConfiguration: UIContentConfiguration, Hashable {
    let tracker: Tracker

    func makeContentView() -> UIView & UIContentView {
        TrackerRowContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> TrackerRowConfiguration { self }
}

final class TrackerRowContentView: UIView, UIContentView {
    var configuration: UIContentConfiguration { didSet { apply() } }

    private let statusDot = UIView()
    private let urlLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()

    init(configuration: TrackerRowConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)

        statusDot.layer.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        urlLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        urlLabel.numberOfLines = 1
        urlLabel.lineBreakMode = .byTruncatingMiddle

        statusLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)

        detailLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        detailLabel.textColor = .secondaryLabel

        let top = UIStackView(arrangedSubviews: [statusDot, urlLabel, statusLabel])
        top.axis = .horizontal
        top.spacing = 8
        top.alignment = .center

        let stack = UIStackView(arrangedSubviews: [top, detailLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func apply() {
        guard let c = configuration as? TrackerRowConfiguration else { return }
        let t = c.tracker
        urlLabel.text = t.url
        let (status, color) = mapStatus(t.status)
        statusLabel.text = status
        statusLabel.textColor = color
        statusDot.backgroundColor = color
        var parts: [String] = []
        if t.numSeeds >= 0 { parts.append("\(t.numSeeds) seeds") }
        if t.numLeeches >= 0 { parts.append("\(t.numLeeches) peers") }
        if t.numDownloaded >= 0 { parts.append("\(t.numDownloaded) downloaded") }
        if !t.msg.isEmpty { parts.append(t.msg) }
        detailLabel.text = parts.joined(separator: "  ·  ")
    }

    private func mapStatus(_ raw: Int) -> (String, UIColor) {
        switch raw {
        case 0: return ("DISABLED", .systemGray)
        case 1: return ("NOT CONTACTED", .systemGray2)
        case 2: return ("WORKING", .systemGreen)
        case 3: return ("UPDATING", Theme.accent)
        case 4: return ("ERROR", Theme.errorColor)
        default: return ("UNKNOWN", .systemGray)
        }
    }
}
