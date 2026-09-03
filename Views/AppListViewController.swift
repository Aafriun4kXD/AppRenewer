import UIKit

class AppListViewController: UIViewController {
    
    private var apps: [InstalledApp] = []
    private var filteredApps: [InstalledApp] = []
    
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private let refreshControl = UIRefreshControl()
    
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Подписанных приложений не найдено"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Приложения"
        view.backgroundColor = .systemBackground
        setupTableView()
        loadApps()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(loadApps)
        )
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AppCell.self, forCellReuseIdentifier: AppCell.identifier)
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(loadApps), for: .valueChanged)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    @objc private func loadApps() {
        apps = AppDetectionService.shared.getInstalledApps()
            .sorted { ($0.daysUntilExpiration ?? 999) < ($1.daysUntilExpiration ?? 999) }
        
        emptyLabel.isHidden = !apps.isEmpty
        tableView.isHidden = apps.isEmpty
        
        tableView.reloadData()
        refreshControl.endRefreshing()
    }
}

extension AppListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return apps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AppCell.identifier, for: indexPath) as! AppCell
        cell.configure(with: apps[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = AppDetailViewController(app: apps[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

class AppCell: UITableViewCell {
    static let identifier = "AppCell"
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let daysLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusDot: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        contentView.addSubview(statusDot)
        contentView.addSubview(nameLabel)
        contentView.addSubview(daysLabel)
        accessoryType = .disclosureIndicator
        
        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 12),
            statusDot.heightAnchor.constraint(equalToConstant: 12),
            
            nameLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            daysLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 12),
            daysLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            daysLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32)
        ])
    }
    
    func configure(with app: InstalledApp) {
        nameLabel.text = app.name
        
        if app.isExpired {
            daysLabel.text = "❌ Истёк"
            daysLabel.textColor = .systemRed
            statusDot.backgroundColor = .systemRed
        } else if let days = app.daysUntilExpiration {
            daysLabel.text = "⚠️ Истекает через \(days) дн."
            daysLabel.textColor = days <= 3 ? .systemRed : .systemOrange
            statusDot.backgroundColor = days <= 3 ? .systemRed : .systemOrange
        } else {
            daysLabel.text = "✅ Активно"
            daysLabel.textColor = .systemGreen
            statusDot.backgroundColor = .systemGreen
        }
    }
}