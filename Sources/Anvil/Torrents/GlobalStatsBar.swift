import UIKit

final class GlobalStatsBar: UIView {
    private let downIcon = UIImageView(image: UIImage(systemName: "arrow.down"))
    private let upIcon = UIImageView(image: UIImage(systemName: "arrow.up"))
    private let downLabel = UILabel()
    private let upLabel = UILabel()
    private let countLabel = UILabel()
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground

        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        configureIcon(downIcon, tint: Theme.downloadColor)
        configureIcon(upIcon, tint: Theme.uploadColor)

        downLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        downLabel.textColor = .label
        upLabel.font = downLabel.font
        upLabel.textColor = .label
        countLabel.font = .systemFont(ofSize: 12, weight: .medium)
        countLabel.textColor = .secondaryLabel

        let downStack = UIStackView(arrangedSubviews: [downIcon, downLabel])
        downStack.axis = .horizontal
        downStack.spacing = 4
        downStack.alignment = .center

        let upStack = UIStackView(arrangedSubviews: [upIcon, upLabel])
        upStack.axis = .horizontal
        upStack.spacing = 4
        upStack.alignment = .center

        let stack = UIStackView(arrangedSubviews: [downStack, upStack, UIView(), countLabel])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.padding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.padding),
        ])

        update(transfer: nil, total: 0, visible: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func configureIcon(_ view: UIImageView, tint: UIColor) {
        view.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .heavy)
        view.tintColor = tint
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 14).isActive = true
        view.heightAnchor.constraint(equalToConstant: 14).isActive = true
    }

    func update(transfer: TransferInfo?, total: Int, visible: Int) {
        downLabel.text = Formatters.speed(transfer?.dlInfoSpeed ?? 0)
        upLabel.text = Formatters.speed(transfer?.upInfoSpeed ?? 0)
        if visible == total {
            countLabel.text = "\(total) torrents"
        } else {
            countLabel.text = "\(visible) of \(total)"
        }
    }
}
