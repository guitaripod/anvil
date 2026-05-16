import UIKit

final class ProgressBar: UIView {
    var progress: Double = 0 {
        didSet { setNeedsLayout() }
    }

    var tintColors: [UIColor] = [Theme.accent, Theme.accent.withAlphaComponent(0.85)] {
        didSet { applyColors() }
    }

    private let trackLayer = CALayer()
    private let fillLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        trackLayer.backgroundColor = UIColor.tertiarySystemFill.cgColor
        trackLayer.cornerRadius = 2
        layer.addSublayer(trackLayer)

        fillLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.endPoint = CGPoint(x: 1, y: 0.5)
        fillLayer.cornerRadius = 2
        layer.addSublayer(fillLayer)
        applyColors()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProgressBar, _: UITraitCollection) in
            view.trackLayer.backgroundColor = UIColor.tertiarySystemFill.cgColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 4)
    }

    private func applyColors() {
        fillLayer.colors = tintColors.map { $0.cgColor }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = bounds
        let clamped = max(0, min(1, progress))
        fillLayer.frame = CGRect(x: 0, y: 0, width: bounds.width * clamped, height: bounds.height)
        CATransaction.commit()
    }
}
