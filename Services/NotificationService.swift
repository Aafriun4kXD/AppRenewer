    import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            print("Уведомления: \(granted ? "разрешены" : "запрещены")")
        }
    }
    
    func scheduleExpirationNotification(for app: InstalledApp) {
        guard let days = app.daysUntilExpiration else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Приложение скоро истечёт"
        content.body = "\(app.name) истечёт через \(days) дн. Нажми чтобы продлить."
        content.sound = .default
        content.userInfo = ["bundleIdentifier": app.bundleIdentifier]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "expiring_\(app.bundleIdentifier)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification(for bundleIdentifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["expiring_\(bundleIdentifier)"]
        )
    }
}