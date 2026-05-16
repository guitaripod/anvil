import UIKit

struct TorrentRowConfiguration: UIContentConfiguration, Hashable {
    let hash: String
    let name: String
    let stateRaw: String
    let progress: Double
    let size: Int64
    let downloaded: Int64
    let dlspeed: Int64
    let upspeed: Int64
    let eta: Int64
    let ratio: Double
    let numSeeds: Int
    let numLeechs: Int

    func makeContentView() -> UIView & UIContentView {
        TorrentRowContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> TorrentRowConfiguration { self }
}

final class TorrentRowContentView: UIView, UIContentView {
    var configuration: UIContentConfiguration {
        didSet { apply() }
    }

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let stateLabel = UILabel()
    private let progressLabel = UILabel()
    private let detailLabel = UILabel()
    private let progressBar = ProgressBar()

    init(configuration: TorrentRowConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingMiddle

        stateLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        stateLabel.setContentHuggingPriority(.required, for: .horizontal)

        progressLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .right
        progressLabel.setContentHuggingPriority(.required, for: .horizontal)

        detailLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 1

        let topRow = UIStackView(arrangedSubviews: [iconView, nameLabel])
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .top

        let stateRow = UIStackView(arrangedSubviews: [stateLabel, progressLabel])
        stateRow.axis = .horizontal
        stateRow.spacing = 6
        stateRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, progressBar, stateRow, detailLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(8, after: topRow)
        stack.setCustomSpacing(6, after: progressBar)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    private func apply() {
        guard let c = configuration as? TorrentRowConfiguration else { return }
        let state = TorrentState.parse(c.stateRaw)
        let color = Theme.color(for: state)

        nameLabel.text = c.name
        iconView.image = UIImage(systemName: Theme.icon(for: state))
        iconView.tintColor = color

        stateLabel.text = Theme.shortLabel(for: state).uppercased()
        stateLabel.textColor = color

        progressLabel.text = Formatters.percent(c.progress)

        progressBar.tintColors = [color, color.withAlphaComponent(0.7)]
        progressBar.progress = c.progress

        detailLabel.text = makeDetail(c, state: state)
    }

    private func makeDetail(_ c: TorrentRowConfiguration, state: TorrentState) -> String {
        var parts: [String] = []
        if state.isDownloading {
            parts.append("\(Formatters.byteCount(c.downloaded)) / \(Formatters.byteCount(c.size))")
            if c.dlspeed > 0 { parts.append("↓ \(Formatters.speed(c.dlspeed))") }
            if c.upspeed > 0 { parts.append("↑ \(Formatters.speed(c.upspeed))") }
            if c.eta > 0 && c.eta < 8_640_000 { parts.append("ETA \(Formatters.eta(c.eta))") }
        } else if state.isSeeding {
            parts.append(Formatters.byteCount(c.size))
            if c.upspeed > 0 { parts.append("↑ \(Formatters.speed(c.upspeed))") }
            parts.append("Ratio \(Formatters.ratio(c.ratio))")
            parts.append("\(c.numLeechs) peers")
        } else {
            parts.append(Formatters.byteCount(c.size))
            parts.append("Ratio \(Formatters.ratio(c.ratio))")
        }
        return parts.joined(separator: "  ·  ")
    }
}
