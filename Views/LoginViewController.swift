import UIKit

class LoginViewController: UIViewController {
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.placeholder = "Apple ID (email)"
        field.borderStyle = .roundedRect
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.placeholder = "Пароль"
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = true
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠️ Используй пароль приложения если включена двухфакторная аутентификация.\nНастройки → appleid.apple.com → Пароли приложений"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loginButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Войти"
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let logoutButton: UIButton = {
        var config = UIButton.Configuration.destructive()
        config.title = "Выйти из Apple ID"
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apple ID"
        view.backgroundColor = .systemBackground
        setupUI()
        loadSavedCredentials()
    }
    
    private func setupUI() {
        view.addSubview(emailField)
        view.addSubview(passwordField)
        view.addSubview(hintLabel)
        view.addSubview(loginButton)
        view.addSubview(logoutButton)
        view.addSubview(activityIndicator)
        
        loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            emailField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            emailField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emailField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emailField.heightAnchor.constraint(equalToConstant: 44),
            
            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 12),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            passwordField.heightAnchor.constraint(equalToConstant: 44),
            
            hintLabel.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            loginButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 24),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            loginButton.heightAnchor.constraint(equalToConstant: 52),
            
            logoutButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 12),
            logoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            logoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            logoutButton.heightAnchor.constraint(equalToConstant: 52),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: logoutButton.bottomAnchor, constant: 24)
        ])
    }
    
    private func loadSavedCredentials() {
        if let credentials = CredentialsStore.shared.load() {
            emailField.text = credentials.email
            passwordField.text = credentials.password
        }
    }
    
    @objc private func login() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty
        else {
            showAlert(title: "Ошибка", message: "Заполни все поля")
            return
        }
        
        activityIndicator.startAnimating()
        loginButton.isEnabled = false
        
        Task {
            do {
                _ = try await AppleAuthService.shared.authenticate(email: email, password: password)
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.loginButton.isEnabled = true
                    self.showAlert(title: "✅ Успех", message: "Apple ID подключён!")
                }
            } catch {
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.loginButton.isEnabled = true
                    self.showAlert(title: "Ошибка", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func logout() {
        CredentialsStore.shared.delete()
        emailField.text = ""
        passwordField.text = ""
        showAlert(title: "Готово", message: "Apple ID отключён")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
