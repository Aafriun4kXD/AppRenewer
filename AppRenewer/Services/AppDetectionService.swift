import Foundation
import MobileCoreServices

class AppDetectionService {
    static let shared = AppDetectionService()
    
    func getInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        
        let fileManager = FileManager.default
        
        let bundlePaths = [
            "/var/containers/Bundle/Application/",
            "/private/var/containers/Bundle/Application/"
        ]
        
        for basePath in bundlePaths {
            guard let appFolders = try? fileManager.contentsOfDirectory(atPath: basePath) else { continue }
            
            for folder in appFolders {
                let appPath = "\(basePath)\(folder)"
                guard let appContents = try? fileManager.contentsOfDirectory(atPath: appPath) else { continue }
                
                for item in appContents where item.hasSuffix(".app") {
                    let fullAppPath = "\(appPath)/\(item)"
                    if let app = parseApp(at: fullAppPath) {
                        apps.append(app)
                    }
                }
            }
        }
        
        return apps.filter { $0.expirationDate != nil }
    }
    
    private func parseApp(at path: String) -> InstalledApp? {
        let infoPlistPath = "\(path)/Info.plist"
        let profilePath = "\(path)/embedded.mobileprovision"
        
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath),
              let bundleId = infoPlist["CFBundleIdentifier"] as? String,
              let name = infoPlist["CFBundleDisplayName"] as? String ?? infoPlist["CFBundleName"] as? String,
              let version = infoPlist["CFBundleShortVersionString"] as? String
        else { return nil }
        
        var expirationDate: Date? = nil
        var profileData: Data? = nil
        
        if let profile = try? Data(contentsOf: URL(fileURLWithPath: profilePath)) {
            profileData = profile
            expirationDate = extractExpirationDate(from: profile)
        }
        
        return InstalledApp(
            id: bundleId,
            bundleIdentifier: bundleId,
            name: name,
            version: version,
            expirationDate: expirationDate,
            provisioningProfileData: profileData
        )
    }
    
    private func extractExpirationDate(from profileData: Data) -> Date? {
        guard let profileString = String(data: profileData, encoding: .ascii) else { return nil }
        
        let startMarker = "<?xml"
        let endMarker = "</plist>"
        
        guard let startRange = profileString.range(of: startMarker),
              let endRange = profileString.range(of: endMarker)
        else { return nil }
        
        let xmlString = String(profileString[startRange.lowerBound...endRange.upperBound])
        guard let xmlData = xmlString.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: xmlData, format: nil) as? [String: Any],
              let expDate = plist["ExpirationDate"] as? Date
        else { return nil }
        
        return expDate
    }
    
    func getAppsBundlePath(for bundleIdentifier: String) -> String? {
        let paths = [
            "/var/containers/Bundle/Application/",
            "/private/var/containers/Bundle/Application/"
        ]
        
        for basePath in paths {
            guard let folders = try? FileManager.default.contentsOfDirectory(atPath: basePath) else { continue }
            for folder in folders {
                let appPath = "\(basePath)\(folder)"
                guard let contents = try? FileManager.default.contentsOfDirectory(atPath: appPath) else { continue }
                for item in contents where item.hasSuffix(".app") {
                    let fullPath = "\(appPath)/\(item)"
                    let plistPath = "\(fullPath)/Info.plist"
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bid = plist["CFBundleIdentifier"] as? String,
                       bid == bundleIdentifier {
                        return fullPath
                    }
                }
            }
        }
        return nil
    }
}