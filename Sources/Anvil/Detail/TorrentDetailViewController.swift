import UIKit
import os

final class TorrentDetailViewController: UIViewController {
    private let api: APIClient
    private var torrent: Torrent
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "detail")

    private let scrollView = UIScrollView()
    private let header = TorrentDetailHeader()
    private let infoCard = InfoCardView()
    private let actionsRow = TorrentActionsRow()
    private let filesRow = NavRowView(symbol: "doc.fill", title: "Files", subtitle: nil)
    private let trackersRow = NavRowView(symbol: "antenna.radiowaves.left.and.right", title: "Trackers", subtitle: nil)

    private var refreshTask: Task<Void, Never>?
    private var properties: TorrentProperties?
    private var trackerCount: Int?

    init(api: APIClient, torrent: Torrent) {
        self.api = api
        self.torrent = torrent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = torrent.name
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: makeMoreMenu())

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        actionsRow.delegate = self
        filesRow.onTap = { [weak self] in
            guard let self else { return }
            navigationController?.pushViewController(TorrentFilesViewController(api: api, hash: torrent.hash, name: torrent.name), animated: true)
        }
        trackersRow.onTap = { [weak self] in
            guard let self else { return }
            navigationController?.pushViewController(TorrentTrackersViewController(api: api, hash: torrent.hash, name: torrent.name), animated: true)
        }

        let stack = UIStackView(arrangedSubviews: [
            header,
            actionsRow,
            sectionTitle("Details"),
            infoCard,
            sectionTitle("Content"),
            wrapCard([filesRow, separator(), trackersRow]),
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(18, after: header)
        stack.setCustomSpacing(18, after: actionsRow)
        stack.setCustomSpacing(18, after: infoCard)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.padding),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.padding),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Theme.padding),
        ])

        header.configure(torrent: torrent)
        infoCard.configure(torrent: torrent, properties: nil)
        actionsRow.configure(torrent: torrent)
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

    private func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabel
        return label
    }

    private func separator() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    private func wrapCard(_ subviews: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = Theme.cornerRadius
        card.layer.cornerCurve = .continuous
        let stack = UIStackView(arrangedSubviews: subviews)
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])
        return card
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refresh() async {
        do {
            let all: [Torrent] = try await api.request(.torrentsInfo())
            try Task.checkCancellation()
            if let updated = all.first(where: { $0.hash == torrent.hash }) {
                torrent = updated
            }
            let p: TorrentProperties = try await api.request(.torrentProperties(hash: torrent.hash))
            try Task.checkCancellation()
            properties = p
            let t: [Tracker] = try await api.request(.torrentTrackers(hash: torrent.hash))
            try Task.checkCancellation()
            trackerCount = t.filter { !$0.url.hasPrefix("**") }.count
            header.configure(torrent: torrent)
            infoCard.configure(torrent: torrent, properties: p)
            actionsRow.configure(torrent: torrent)
            trackersRow.update(subtitle: "\(trackerCount ?? 0)")
        } catch is CancellationError {
            return
        } catch {
            log.error("Detail refresh failed: \(error)")
        }
    }

    private func makeMoreMenu() -> UIMenu {
        let copy = UIAction(title: "Copy magnet link", image: UIImage(systemName: "link")) { [weak self] _ in
            UIPasteboard.general.string = self?.torrent.magnetUri
            if let self {
                let toast = ToastView(text: "Magnet copied", symbol: "checkmark.circle.fill")
                toast.show(in: view)
            }
        }
        let recheck = UIAction(title: "Force recheck", image: UIImage(systemName: "checkmark.shield")) { [weak self] _ in
            guard let self else { return }
            Task { try? await self.api.requestVoid(.recheck(hashes: [self.torrent.hash])) }
        }
        let reannounce = UIAction(title: "Reannounce", image: UIImage(systemName: "antenna.radiowaves.left.and.right")) { [weak self] _ in
            guard let self else { return }
            Task { try? await self.api.requestVoid(.reannounce(hashes: [self.torrent.hash])) }
        }
        let delete = UIAction(title: "Delete…", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.confirmDelete()
        }
        return UIMenu(children: [copy, recheck, reannounce, delete])
    }

    private func confirmDelete() {
        let alert = UIAlertController(title: "Delete torrent?", message: torrent.name, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove from list", style: .default) { [weak self] _ in
            self?.delete(withFiles: false)
        })
        alert.addAction(UIAlertAction(title: "Remove and delete files", style: .destructive) { [weak self] _ in
            self?.delete(withFiles: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    private func delete(withFiles: Bool) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await api.requestVoid(.delete(hashes: [torrent.hash], deleteFiles: withFiles))
                navigationController?.popViewController(animated: true)
            } catch {
                log.error("Delete failed: \(error)")
                let alert = UIAlertController(title: "Delete failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

extension TorrentDetailViewController: TorrentActionsRowDelegate {
    func actionsRowDidTapToggle() {
        let state = TorrentState.parse(torrent.state)
        Task { [weak self] in
            guard let self else { return }
            do {
                if state.isStopped {
                    try await api.requestVoid(.start(hashes: [torrent.hash]))
                } else {
                    try await api.requestVoid(.stop(hashes: [torrent.hash]))
                }
                await refresh()
            } catch {
                log.error("Toggle failed: \(error)")
            }
        }
    }

    func actionsRowDidTapForceStart() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await api.requestVoid(.forceStart(hashes: [torrent.hash], value: !torrent.forceStart))
                await refresh()
            } catch {
                log.error("Force start failed: \(error)")
            }
        }
    }
}

final class TorrentDetailHeader: UIView {
    private let nameLabel = UILabel()
    private let stateLabel = UILabel()
    private let stateDot = UIView()
    private let progressBar = ProgressBar()
    private let percentLabel = UILabel()
    private let downSpeedLabel = UILabel()
    private let upSpeedLabel = UILabel()
    private let etaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = Theme.cornerRadiusLarge
        layer.cornerCurve = .continuous

        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        nameLabel.numberOfLines = 0

        stateDot.translatesAutoresizingMaskIntoConstraints = false
        stateDot.layer.cornerRadius = 4

        stateLabel.font = .systemFont(ofSize: 12, weight: .heavy)

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        percentLabel.textColor = .secondaryLabel
        percentLabel.textAlignment = .right

        let stateStack = UIStackView(arrangedSubviews: [stateDot, stateLabel, UIView(), percentLabel])
        stateStack.axis = .horizontal
        stateStack.spacing = 6
        stateStack.alignment = .center
        stateDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        stateDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        downSpeedLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        upSpeedLabel.font = downSpeedLabel.font
        etaLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        etaLabel.textColor = .secondaryLabel

        let downStack = makeRow(symbol: "arrow.down", tint: Theme.downloadColor, label: downSpeedLabel)
        let upStack = makeRow(symbol: "arrow.up", tint: Theme.uploadColor, label: upSpeedLabel)
        let speedStack = UIStackView(arrangedSubviews: [downStack, upStack, UIView(), etaLabel])
        speedStack.axis = .horizontal
        speedStack.spacing = 16
        speedStack.alignment = .center

        let mainStack = UIStackView(arrangedSubviews: [nameLabel, stateStack, progressBar, speedStack])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.setCustomSpacing(8, after: stateStack)
        mainStack.setCustomSpacing(12, after: progressBar)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func makeRow(symbol: String, tint: UIColor, label: UILabel) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .heavy)
        icon.tintColor = tint
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }

    func configure(torrent: Torrent) {
        let state = TorrentState.parse(torrent.state)
        let color = Theme.color(for: state)
        nameLabel.text = torrent.name
        stateDot.backgroundColor = color
        stateLabel.text = Theme.shortLabel(for: state).uppercased()
        stateLabel.textColor = color
        percentLabel.text = Formatters.percent(torrent.progress)
        progressBar.tintColors = [color, color.withAlphaComponent(0.7)]
        progressBar.progress = torrent.progress
        downSpeedLabel.text = Formatters.speed(torrent.dlspeed)
        upSpeedLabel.text = Formatters.speed(torrent.upspeed)
        if state.isDownloading && torrent.eta > 0 && torrent.eta < 8_640_000 {
            etaLabel.text = "ETA " + Formatters.eta(torrent.eta)
            etaLabel.isHidden = false
        } else {
            etaLabel.isHidden = true
        }
    }
}

final class InfoCardView: UIView {
    private enum Key: Int, CaseIterable {
        case size, downloaded, uploaded, ratio, seeds, peers
        case added, completed, lastActive, activeFor
        case pieces, savePath, hash, isPrivate

        var label: String {
            switch self {
            case .size: return "Size"
            case .downloaded: return "Downloaded"
            case .uploaded: return "Uploaded"
            case .ratio: return "Ratio"
            case .seeds: return "Seeds"
            case .peers: return "Peers"
            case .added: return "Added"
            case .completed: return "Completed"
            case .lastActive: return "Last active"
            case .activeFor: return "Active for"
            case .pieces: return "Pieces"
            case .savePath: return "Save path"
            case .hash: return "Hash"
            case .isPrivate: return "Private"
            }
        }
    }

    private let stack = UIStackView()
    private var rows: [Key: InfoRow] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = Theme.cornerRadius
        layer.cornerCurve = .continuous
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let ordered = Key.allCases
        for (index, key) in ordered.enumerated() {
            let row = InfoRow(label: key.label)
            rows[key] = row
            stack.addArrangedSubview(row)
            if index < ordered.count - 1 {
                stack.addArrangedSubview(Self.makeSeparator())
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        let wrap = UIView()
        wrap.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: wrap.topAnchor),
            sep.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        return wrap
    }

    func configure(torrent: Torrent, properties: TorrentProperties?) {
        rows[.size]?.setValue(Formatters.byteCount(torrent.size))
        rows[.downloaded]?.setValue(Formatters.byteCount(torrent.downloaded))
        rows[.uploaded]?.setValue(Formatters.byteCount(torrent.uploaded))
        rows[.ratio]?.setValue(Formatters.ratio(torrent.ratio))
        rows[.seeds]?.setValue("\(torrent.numSeeds) connected / \(torrent.numComplete) total")
        rows[.peers]?.setValue("\(torrent.numLeechs) connected / \(torrent.numIncomplete) total")
        rows[.added]?.setValue(Formatters.absoluteDate(torrent.addedOn))
        rows[.completed]?.setValue(torrent.completionOn > 0 ? Formatters.absoluteDate(torrent.completionOn) : "—")
        rows[.lastActive]?.setValue(Formatters.relativeDate(torrent.lastActivity))
        rows[.activeFor]?.setValue(Formatters.duration(torrent.timeActive))
        rows[.pieces]?.setValue(properties.map { "\($0.piecesHave) / \($0.piecesNum) (\(Formatters.byteCount($0.pieceSize)))" } ?? "—")
        rows[.savePath]?.setValue(torrent.savePath)
        rows[.hash]?.setValue(torrent.hash)
        rows[.isPrivate]?.setValue((torrent.isPrivate ?? false) ? "Yes" : "No")
    }
}

final class InfoRow: UIView {
    private let valueLabel = UILabel()

    init(label: String) {
        super.init(frame: .zero)
        let key = UILabel()
        key.text = label
        key.font = .systemFont(ofSize: 14, weight: .regular)
        key.textColor = .secondaryLabel
        key.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = .systemFont(ofSize: 14, weight: .medium)
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .right

        let stack = UIStackView(arrangedSubviews: [key, valueLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .firstBaseline
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
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

    func setValue(_ value: String) {
        valueLabel.text = value
    }
}

@MainActor
protocol TorrentActionsRowDelegate: AnyObject {
    func actionsRowDidTapToggle()
    func actionsRowDidTapForceStart()
}

final class TorrentActionsRow: UIView {
    weak var delegate: TorrentActionsRowDelegate?
    private let toggleButton = UIButton(configuration: .filled())
    private let forceButton = UIButton(configuration: .gray())

    override init(frame: CGRect) {
        super.init(frame: frame)
        toggleButton.addAction(UIAction { [weak self] _ in self?.delegate?.actionsRowDidTapToggle() }, for: .touchUpInside)
        forceButton.addAction(UIAction { [weak self] _ in self?.delegate?.actionsRowDidTapForceStart() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [toggleButton, forceButton])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
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

    func configure(torrent: Torrent) {
        let state = TorrentState.parse(torrent.state)
        var toggleCfg = UIButton.Configuration.filled()
        toggleCfg.title = state.isStopped ? "Start" : "Stop"
        toggleCfg.image = UIImage(systemName: state.isStopped ? "play.fill" : "pause.fill")
        toggleCfg.imagePadding = 6
        toggleCfg.cornerStyle = .large
        toggleCfg.baseBackgroundColor = state.isStopped ? Theme.uploadColor : Theme.checkingColor
        toggleCfg.baseForegroundColor = .white
        toggleCfg.buttonSize = .large
        toggleButton.configuration = toggleCfg

        var forceCfg = UIButton.Configuration.gray()
        forceCfg.title = torrent.forceStart ? "Unforce" : "Force start"
        forceCfg.image = UIImage(systemName: "bolt.fill")
        forceCfg.imagePadding = 6
        forceCfg.cornerStyle = .large
        forceCfg.buttonSize = .large
        forceButton.configuration = forceCfg
    }
}

final class NavRowView: UIView {
    var onTap: (() -> Void)?
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let iconView = UIImageView()

    init(symbol: String, title: String, subtitle: String?) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = Theme.accent
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.contentMode = .center
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)

        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        chevron.tintColor = .tertiaryLabel
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), subtitleLabel, chevron])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let tap = ClosureTapGesture { [weak self] in self?.onTap?() }
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(subtitle: String?) {
        subtitleLabel.text = subtitle
    }
}
