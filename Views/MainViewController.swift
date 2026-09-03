import UIKit

class MainViewController: UIViewController {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AppRenewer"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Мониторинг и продление подписанных приложений"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let appsButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Мои приложения"
        config.image = UIImage(systemName: "apps.iphone")
        config.imagePadding = 8
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loginButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Apple ID"
        config.image = UIImage(systemName: "person.circle")
        config.imagePadding = 8
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let statusView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        updateStatus()
        NotificationService.shared.requestPermission()
        BackgroundTaskManager.shared.scheduleAppCheck()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(statusView)
        statusView.addSubview(statusLabel)
        view.addSubview(appsButton)
        view.addSubview(loginButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            statusView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            statusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            statusLabel.topAnchor.constraint(equalTo: statusView.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: statusView.bottomAnchor, constant: -16),
            
            appsButton.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: 32),
            appsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            appsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            appsButton.heightAnchor.constraint(equalToConstant: 52),
            
            loginButton.topAnchor.constraint(equalTo: appsButton.bottomAnchor, constant: 12),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            loginButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }
    
    private func setupActions() {
        appsButton.addTarget(self, action: #selector(showApps), for: .touchUpInside)
        loginButton.addTarget(self, action: #selector(showLogin), for: .touchUpInside)
    }
    
    private func updateStatus() {
        let apps = AppDetectionService.shared.getInstalledApps()
        let expiring = apps.filter { $0.isExpiringSoon }.count
        let expired = apps.filter { $0.isExpired }.count
        let credentials = CredentialsStore.shared.load()
        
        var statusText = "📱 Найдено приложений: \(apps.count)\n"
        statusText += "⚠️ Истекают скоро: \(expiring)\n"
        statusText += "❌ Истекли: \(expired)\n"
        statusText += credentials != nil ? "✅ Apple ID подключён" : "❌ Apple ID не настроен"
        
        statusLabel.text = statusText
    }
    
    @objc private func showApps() {
        let vc = AppListViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func showLogin() {
        let vc = LoginViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}