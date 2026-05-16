import UIKit
import os

final class AddTorrentViewController: UIViewController {
    private let api: APIClient
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "add")

    private let textView = UITextView()
    private let textViewPlaceholder = UILabel()
    private let pasteButton = UIButton(configuration: .gray())
    private let clearButton = UIButton(configuration: .gray())
    private let pausedSwitch = UISwitch()
    private let skipCheckSwitch = UISwitch()
    private let savePathField = UITextField()
    private let categoryField = UITextField()
    private let submitButton = UIButton(configuration: .filled())
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(api: APIClient) {
        self.api = api
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Torrent"
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.layer.cornerRadius = Theme.cornerRadius
        textView.layer.cornerCurve = .continuous
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true

        textViewPlaceholder.text = "Paste a magnet link or .torrent URL.\nOne per line for multiple torrents."
        textViewPlaceholder.font = textView.font
        textViewPlaceholder.textColor = .tertiaryLabel
        textViewPlaceholder.numberOfLines = 0
        textViewPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(textViewPlaceholder)
        NSLayoutConstraint.activate([
            textViewPlaceholder.topAnchor.constraint(equalTo: textView.topAnchor, constant: 18),
            textViewPlaceholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 17),
            textViewPlaceholder.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -17),
        ])

        var pasteCfg = UIButton.Configuration.gray()
        pasteCfg.title = "Paste"
        pasteCfg.image = UIImage(systemName: "doc.on.clipboard")
        pasteCfg.imagePadding = 6
        pasteCfg.cornerStyle = .medium
        pasteButton.configuration = pasteCfg
        pasteButton.addAction(UIAction { [weak self] _ in self?.pasteFromClipboard() }, for: .touchUpInside)

        var clearCfg = UIButton.Configuration.gray()
        clearCfg.title = "Clear"
        clearCfg.image = UIImage(systemName: "xmark")
        clearCfg.imagePadding = 6
        clearCfg.cornerStyle = .medium
        clearButton.configuration = clearCfg
        clearButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            textView.text = ""
            textViewPlaceholder.isHidden = false
            updateSubmitState()
        }, for: .touchUpInside)

        let buttonsStack = UIStackView(arrangedSubviews: [pasteButton, clearButton])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 8
        buttonsStack.distribution = .fillEqually

        let optionsCard = makeOptionsCard()

        var submitCfg = UIButton.Configuration.filled()
        submitCfg.title = "Add Torrent"
        submitCfg.image = UIImage(systemName: "plus.circle.fill")
        submitCfg.imagePadding = 8
        submitCfg.cornerStyle = .large
        submitCfg.baseBackgroundColor = Theme.accent
        submitCfg.baseForegroundColor = .white
        submitCfg.buttonSize = .large
        submitButton.configuration = submitCfg
        submitButton.isEnabled = false
        submitButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)

        spinner.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            sectionLabel("LINK OR URL"),
            textView,
            buttonsStack,
            sectionLabel("OPTIONS"),
            optionsCard,
            submitButton,
            spinner,
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(20, after: buttonsStack)
        stack.setCustomSpacing(20, after: optionsCard)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Theme.padding),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Theme.padding),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -2 * Theme.padding),
        ])
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabel
        return label
    }

    private func makeOptionsCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = Theme.cornerRadius
        card.layer.cornerCurve = .continuous

        let pausedRow = makeSwitchRow(title: "Start paused", symbol: "pause.fill", control: pausedSwitch)
        let skipRow = makeSwitchRow(title: "Skip hash check", symbol: "checkmark.shield", control: skipCheckSwitch)

        let pathRow = makeFieldRow(symbol: "folder", placeholder: "Save path (optional)", field: savePathField)
        savePathField.autocapitalizationType = .none
        savePathField.autocorrectionType = .no

        let categoryRow = makeFieldRow(symbol: "tag", placeholder: "Category (optional)", field: categoryField)
        categoryField.autocapitalizationType = .none
        categoryField.autocorrectionType = .no

        let stack = UIStackView(arrangedSubviews: [pausedRow, separator(), skipRow, separator(), pathRow, separator(), categoryRow])
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

    private func separator() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return view
    }

    private func makeSwitchRow(title: String, symbol: String, control: UISwitch) -> UIView {
        control.onTintColor = Theme.accent
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .center
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .regular)

        let stack = UIStackView(arrangedSubviews: [icon, label, UIView(), control])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return stack
    }

    private func makeFieldRow(symbol: String, placeholder: String, field: UITextField) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .center
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16, weight: .regular)
        field.borderStyle = .none
        field.returnKeyType = .done

        let stack = UIStackView(arrangedSubviews: [icon, field])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return stack
    }

    private func pasteFromClipboard() {
        guard let clip = UIPasteboard.general.string, !clip.isEmpty else { return }
        let existing = textView.text ?? ""
        if existing.isEmpty {
            textView.text = clip
        } else {
            textView.text = existing + "\n" + clip
        }
        textViewPlaceholder.isHidden = !(textView.text ?? "").isEmpty
        updateSubmitState()
    }

    private func updateSubmitState() {
        let hasContent = !(textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        submitButton.isEnabled = hasContent
    }

    private func submit() {
        view.endEditing(true)
        let raw = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let lines = raw
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let urls = lines.joined(separator: "\n")

        spinner.startAnimating()
        submitButton.isEnabled = false

        Task { [weak self] in
            guard let self else { return }
            do {
                try await api.requestVoid(.addTorrentByURL(
                    urls: urls,
                    savepath: savePathField.text,
                    category: categoryField.text,
                    paused: pausedSwitch.isOn,
                    skipChecking: skipCheckSwitch.isOn
                ))
                spinner.stopAnimating()
                clearAndConfirm(count: lines.count)
            } catch {
                log.error("Add failed: \(error)")
                spinner.stopAnimating()
                submitButton.isEnabled = true
                let alert = UIAlertController(title: "Add failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    private func clearAndConfirm(count: Int) {
        textView.text = ""
        textViewPlaceholder.isHidden = false
        let toast = ToastView(text: count == 1 ? "Torrent added" : "\(count) torrents added", symbol: "checkmark.circle.fill")
        toast.show(in: view)
        updateSubmitState()
    }
}

extension AddTorrentViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        textViewPlaceholder.isHidden = !textView.text.isEmpty
        updateSubmitState()
    }
}
