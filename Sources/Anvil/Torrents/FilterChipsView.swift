import UIKit

final class FilterChipsView: UIView {
    var onSelect: ((TorrentFilter) -> Void)?
    private(set) var selected: TorrentFilter = .all {
        didSet { refreshSelection() }
    }
    private var counts: [TorrentFilter: Int] = [:]
    private let stack = UIStackView()
    private let scrollView = UIScrollView()
    private var buttons: [TorrentFilter: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        for filter in TorrentFilter.allCases {
            let button = makeButton(for: filter)
            buttons[filter] = button
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: Theme.padding),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -Theme.padding),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -12),
        ])
        refreshSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 48)
    }

    func setSelected(_ filter: TorrentFilter) {
        selected = filter
    }

    func setCounts(_ counts: [TorrentFilter: Int]) {
        self.counts = counts
        for (filter, button) in buttons {
            applyConfiguration(to: button, filter: filter, isSelected: filter == selected)
        }
    }

    private func makeButton(for filter: TorrentFilter) -> UIButton {
        let button = UIButton()
        button.configurationUpdateHandler = nil
        applyConfiguration(to: button, filter: filter, isSelected: filter == selected)
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            selected = filter
            onSelect?(filter)
        }, for: .touchUpInside)
        return button
    }

    private func applyConfiguration(to button: UIButton, filter: TorrentFilter, isSelected: Bool) {
        var config: UIButton.Configuration = isSelected ? .filled() : .gray()
        config.image = UIImage(systemName: filter.symbol)
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        var title = filter.title
        if let count = counts[filter] {
            title += "  \(count)"
        }
        let titleColor: UIColor = isSelected ? .white : .label
        var attr = AttributedString(title)
        attr.font = .systemFont(ofSize: 13, weight: .semibold)
        attr.foregroundColor = titleColor
        config.attributedTitle = attr
        config.baseBackgroundColor = isSelected ? filter.tint : .secondarySystemFill
        config.baseForegroundColor = isSelected ? .white : .label
        button.configuration = config
    }

    private func refreshSelection() {
        for (filter, button) in buttons {
            applyConfiguration(to: button, filter: filter, isSelected: filter == selected)
        }
    }
}
