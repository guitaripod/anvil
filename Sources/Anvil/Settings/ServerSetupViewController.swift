import UIKit
import os

final class ServerSetupViewController: UIViewController {
    var onConnected: ((APIClient) -> Void)?

    private let urlField = UITextField()
    private let usernameField = UITextField()
    private let passwordField = UITextField()
    private let connectButton = UIButton(configuration: .filled())
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let log = Logger(subsystem: "com.guitaripod.anvil", category: "setup")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)
        let icon = UIImageView(image: UIImage(systemName: "hammer.fill", withConfiguration: iconConfig))
        icon.tintColor = Theme.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Anvil"
        titleLabel.font = .systemFont(ofSize: 36, weight: .heavy)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Connect to your qBittorrent server"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let urlGroup = makeFieldGroup(symbol: "network", field: urlField, placeholder: "http://host:\(ServerBootstrap.defaultPort)")
        urlField.keyboardType = .URL
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        if let last = ServerBootstrap.lastBaseURL() {
            urlField.text = last.absoluteString
        }
        urlField.returnKeyType = .next
        urlField.addAction(UIAction { [weak self] _ in self?.usernameField.becomeFirstResponder() }, for: .editingDidEndOnExit)

        let userGroup = makeFieldGroup(symbol: "person.fill", field: usernameField, placeholder: "Username")
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.text = "admin"
        usernameField.returnKeyType = .next
        usernameField.addAction(UIAction { [weak self] _ in self?.passwordField.becomeFirstResponder() }, for: .editingDidEndOnExit)

        let passGroup = makeFieldGroup(symbol: "lock.fill", field: passwordField, placeholder: "Password")
        passwordField.isSecureTextEntry = true
        passwordField.autocapitalizationType = .none
        passwordField.autocorrectionType = .no
        passwordField.returnKeyType = .go
        passwordField.addAction(UIAction { [weak self] _ in self?.attemptConnect() }, for: .editingDidEndOnExit)

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = "Connect"
        buttonConfig.image = UIImage(systemName: "arrow.right")
        buttonConfig.imagePlacement = .trailing
        buttonConfig.imagePadding = 10
        buttonConfig.cornerStyle = .large
        buttonConfig.baseBackgroundColor = Theme.accent
        buttonConfig.baseForegroundColor = .white
        buttonConfig.buttonSize = .large
        connectButton.configuration = buttonConfig
        connectButton.addAction(UIAction { [weak self] _ in self?.attemptConnect() }, for: .touchUpInside)

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .systemRed
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        spinner.hidesWhenStopped = true

        let fieldsStack = UIStackView(arrangedSubviews: [urlGroup, userGroup, passGroup])
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 12

        let stack = UIStackView(arrangedSubviews: [
            icon, titleLabel, subtitleLabel, fieldsStack, connectButton, statusLabel, spinner,
        ])
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(6, after: titleLabel)
        stack.setCustomSpacing(32, after: subtitleLabel)
        stack.setCustomSpacing(20, after: fieldsStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -16),
        ])

        let tap = ClosureTapGesture { [weak self] in self?.view.endEditing(true) }
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func makeFieldGroup(symbol: String, field: UITextField, placeholder: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = .tertiaryLabel
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 17, weight: .regular)
        field.borderStyle = .none
        field.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [icon, field])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = Theme.cornerRadius
        container.layer.cornerCurve = .continuous
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    private func attemptConnect() {
        view.endEditing(true)
        let urlRaw = (urlField.text ?? "").trimmingCharacters(in: .whitespaces)
        let user = (usernameField.text ?? "").trimmingCharacters(in: .whitespaces)
        let pass = passwordField.text ?? ""

        guard !urlRaw.isEmpty else { return showStatus("Enter the server URL", color: .systemRed) }
        let normalized = urlRaw.hasPrefix("http") ? urlRaw : "http://" + urlRaw
        guard let url = URL(string: normalized), url.scheme != nil, url.host != nil else {
            return showStatus("Invalid URL", color: .systemRed)
        }
        guard !user.isEmpty else { return showStatus("Enter the username", color: .systemRed) }
        guard !pass.isEmpty else { return showStatus("Enter the password", color: .systemRed) }

        ServerBootstrap.setLastBaseURL(url)

        spinner.startAnimating()
        connectButton.isEnabled = false
        showStatus("Connecting to \(url.host ?? "server")…", color: .secondaryLabel)

        Task { [weak self] in
            guard let self else { return }
            do {
                let reachable = await APIClient.probe(baseURL: url)
                guard reachable else {
                    showStatus("Could not reach \(url.host ?? "server")", color: .systemRed)
                    spinner.stopAnimating()
                    connectButton.isEnabled = true
                    return
                }

                let session = ServerSession(baseURL: url, username: user, password: pass)
                let api = APIClient(session: session)
                try await api.login()

                ServerBootstrap.save(baseURL: url, username: user, password: pass)
                showStatus("Connected", color: .systemGreen)
                try? await Task.sleep(for: .milliseconds(250))
                spinner.stopAnimating()
                onConnected?(api)
            } catch {
                log.error("Connect failed: \(error)")
                showStatus(error.localizedDescription, color: .systemRed)
                spinner.stopAnimating()
                connectButton.isEnabled = true
            }
        }
    }

    private func showStatus(_ text: String, color: UIColor) {
        statusLabel.text = text
        statusLabel.textColor = color
        statusLabel.isHidden = false
    }
}
