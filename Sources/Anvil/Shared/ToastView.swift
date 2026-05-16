import UIKit

final class ToastView: UIView {
    init(text: String, symbol: String?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.label.withAlphaComponent(0.9)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .systemBackground

        let icon = UIImageView(image: symbol.map { UIImage(systemName: $0) ?? UIImage() })
        icon.tintColor = .systemBackground
        icon.contentMode = .scaleAspectFit
        icon.isHidden = symbol == nil
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show(in parent: UIView, duration: TimeInterval = 1.6) {
        parent.addSubview(self)
        let bottom = bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: 40)
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            bottom,
        ])
        alpha = 0
        parent.layoutIfNeeded()
        bottom.constant = -80
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            parent.layoutIfNeeded()
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: duration, options: .curveEaseIn) {
                self.alpha = 0
            } completion: { _ in
                self.removeFromSuperview()
            }
        }
    }
}
