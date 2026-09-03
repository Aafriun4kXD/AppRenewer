import Foundation
import BackgroundTasks

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    let checkTaskIdentifier = "com.apprenewer.checkApps"
    
    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: checkTaskIdentifier, using: nil) { task in
            self.handleAppCheckTask(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleAppCheck() {
        let request = BGAppRefreshTaskRequest(identifier: checkTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6)
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleAppCheckTask(task: BGAppRefreshTask) {
        scheduleAppCheck()
        
        let apps = AppDetectionService.shared.getInstalledApps()
        let expiringApps = apps.filter { $0.isExpiringSoon || $0.isExpired }
        
        for app in expiringApps {
            NotificationService.shared.scheduleExpirationNotification(for: app)
        }
        
        task.setTaskCompleted(success: true)
    }
}