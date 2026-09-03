import Foundation

struct InstalledApp: Identifiable, Codable {
    let id: String
    let bundleIdentifier: String
    let name: String
    let version: String
    let expirationDate: Date?
    let provisioningProfileData: Data?
    
    var daysUntilExpiration: Int? {
        guard let expDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expDate).day
    }
    
    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days <= 7 && days >= 0
    }
    
    var isExpired: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days < 0
    }
    
    var statusColor: String {
        if isExpired { return "red" }
        if isExpiringSoon { return "orange" }
        return "green"
    }
}