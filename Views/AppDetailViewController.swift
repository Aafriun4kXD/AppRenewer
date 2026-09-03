import UIKit

class AppDetailViewController: UIViewController {
    
    private let app: InstalledApp
    private let renewButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Продлить сейчас"
        config.image = UIImage(systemName: "arrow.clockwise.circle.fill")
        config.imagePadding = 8
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let infoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(app: InstalledApp) {
        self.app = app
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = app.name
        view.backgroundColor = .systemBackground
        setupUI()
        populateInfo()
    }
    
    private func setupUI() {
        view.addSubview(infoStack)
        view.addSubview(renewButton)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        
        renewButton.addTarget(self, action: #selector(renewApp), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            infoStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            infoStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            renewButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            renewButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            renewButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            renewButton.heightAnchor.constraint(equalToConstant: 52),
            
            statusLabel.bottomAnchor.constraint(equalTo: renewButton.topAnchor, constant: -16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -16)
        ])
    }
    
    private func populateInfo() {
        let infos: [(String, String)] = [
            ("📦 Bundle ID", app.bundleIdentifier),
            ("🔢 Версия", app.version),
            ("📅 Истекает", {
                if let date = app.expirationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    return formatter.string(from: date)
                }
                return "Неизвестно"
            }()),
            ("⏳ Осталось", app.daysUntilExpiration.map { "\($0) дней" } ?? "N/A"),
            ("🔴 Статус", app.isExpired ? "Истёк" : app.isExpiringSoon ? "Истекает скоро" : "Активен")
        ]
        
        for (key, value) in infos {
            let row = makeInfoRow(key: key, value: value)
            infoStack.addArrangedSubview(row)
        }
    }
    
    private func makeInfoRow(key: String, value: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 10
        
        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(keyLabel)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            keyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: keyLabel.trailingAnchor, constant: 8),
            
            container.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return container
    }
    
    @objc private func renewApp() {
        guard let credentials = CredentialsStore.shared.load() else {
            showAlert(title: "⚠️ Apple ID не настроен", message: "Сначала войди в Apple ID в настройках")
            return
        }
        
        activityIndicator.startAnimating()
        renewButton.isEnabled = false
        statusLabel.text = "Получаем сертификат..."
        
        Task {
            do {
                await MainActor.run { self.statusLabel.text = "Авторизуемся в Apple..." }
                
                let freshCredentials = try await AppleAuthService.shared.authenticate(
                    email: credentials.email,
                    password: credentials.password
                )
                
                await MainActor.run { self.statusLabel.text = "Получаем профиль подписи..." }
                
                try await AppSigningService.shared.renewApp(app, credentials: freshCredentials)
                
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.renewButton.isEnabled = true
                    self.statusLabel.text = "✅ Готово!"
                    NotificationService.shared.cancelNotification(for: self.app.bundleIdentifier)
                    self.showAlert(title: "✅ Успех!", message: "\(self.app.name) продлено на 7 дней!")
                }
            } catch {
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.renewButton.isEnabled = true
                    self.statusLabel.text = "❌ Ошибка"
                    self.showAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}