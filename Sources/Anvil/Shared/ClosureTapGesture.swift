import UIKit

final class ClosureTapGesture: UITapGestureRecognizer {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(invoke))
    }

    @objc private func invoke() { handler() }
}
