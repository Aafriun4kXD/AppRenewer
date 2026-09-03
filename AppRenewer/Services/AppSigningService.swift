import Foundation

class AppSigningService {
    static let shared = AppSigningService()
    
    private let altStoreSourceURL = "https://cdn.altstore.io/file/altstore/apps.json"
    
    func renewApp(_ app: InstalledApp, credentials: AppleIDCredentials) async throws {
        guard let session = credentials.session, session.isValid else {
            throw SigningError.invalidSession
        }
        
        let certificate = try await fetchDeveloperCertificate(credentials: credentials)
        let profile = try await fetchProvisioningProfile(
            bundleId: app.bundleIdentifier,
            certificate: certificate,
            credentials: credentials
        )
        try await installProfile(profile, for: app)
    }
    
    private struct DeveloperCertificate {
        let data: Data
        let privateKey: Data
        let expirationDate: Date
    }
    
    private func fetchDeveloperCertificate(credentials: AppleIDCredentials) async throws -> DeveloperCertificate {
        guard let session = credentials.session else { throw SigningError.invalidSession }
        
        let teamID = try await getTeamID(credentials: credentials)
        
        var request = URLRequest(url: URL(string: "https://developerservices2.apple.com/services/v1/certificates")!)
        request.httpMethod = "POST"
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "data": [
                "type": "certificates",
                "attributes": [
                    "certificateType": "IOS_DEVELOPMENT",
                    "csrContent": generateCSR()
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let certData = json["data"] as? [String: Any],
              let attrs = certData["attributes"] as? [String: Any],
              let certContent = attrs["certificateContent"] as? String,
              let certData = Data(base64Encoded: certContent)
        else {
            throw SigningError.certificateFetchFailed
        }
        
        return DeveloperCertificate(
            data: certData,
            privateKey: Data(),
            expirationDate: Date().addingTimeInterval(60 * 60 * 24 * 7)
        )
    }
    
    private func getTeamID(credentials: AppleIDCredentials) async throws -> String {
        guard let session = credentials.session else { throw SigningError.invalidSession }
        
        var request = URLRequest(url: URL(string: "https://developerservices2.apple.com/services/v1/teams")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let teams = json["data"] as? [[String: Any]],
              let firstTeam = teams.first,
              let attrs = firstTeam["attributes"] as? [String: Any],
              let teamID = attrs["teamId"] as? String
        else {
            throw SigningError.teamFetchFailed
        }
        
        return teamID
    }
    
    private func fetchProvisioningProfile(bundleId: String, certificate: DeveloperCertificate, credentials: AppleIDCredentials) async throws -> Data {
        guard let session = credentials.session else { throw SigningError.invalidSession }
        
        var request = URLRequest(url: URL(string: "https://developerservices2.apple.com/services/v1/bundleIds")!)
        request.httpMethod = "POST"
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let bundleBody: [String: Any] = [
            "data": [
                "type": "bundleIds",
                "attributes": [
                    "identifier": bundleId,
                    "name": bundleId.replacingOccurrences(of: ".", with: "-"),
                    "platform": "IOS"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: bundleBody)
        
        let (bundleData, _) = try await URLSession.shared.data(for: request)
        guard let bundleJson = try? JSONSerialization.jsonObject(with: bundleData) as? [String: Any],
              let bundleDataObj = bundleJson["data"] as? [String: Any],
              let bundleID = bundleDataObj["id"] as? String
        else {
            throw SigningError.bundleIdFailed
        }
        
        var profileRequest = URLRequest(url: URL(string: "https://developerservices2.apple.com/services/v1/profiles")!)
        profileRequest.httpMethod = "POST"
        profileRequest.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        profileRequest.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let profileBody: [String: Any] = [
            "data": [
                "type": "profiles",
                "attributes": [
                    "name": "\(bundleId)_profile",
                    "profileType": "IOS_APP_DEVELOPMENT"
                ],
                "relationships": [
                    "bundleId": ["data": ["type": "bundleIds", "id": bundleID]],
                    "certificates": ["data": [["type": "certificates", "id": "CERT_ID"]]]
                ]
            ]
        ]
        
        profileRequest.httpBody = try JSONSerialization.data(withJSONObject: profileBody)
        
        let (profileData, _) = try await URLSession.shared.data(for: profileRequest)
        guard let profileJson = try? JSONSerialization.jsonObject(with: profileData) as? [String: Any],
              let profDataObj = profileJson["data"] as? [String: Any],
              let profAttrs = profDataObj["attributes"] as? [String: Any],
              let profileContent = profAttrs["profileContent"] as? String,
              let decodedProfile = Data(base64Encoded: profileContent)
        else {
            throw SigningError.profileFetchFailed
        }
        
        return decodedProfile
    }
    
    private func installProfile(_ profileData: Data, for app: InstalledApp) async throws {
        guard let appPath = AppDetectionService.shared.getAppsBundlePath(for: app.bundleIdentifier) else {
            throw SigningError.appPathNotFound
        }
        
        let profilePath = "\(appPath)/embedded.mobileprovision"
        
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw SigningError.appPathNotFound
        }
        
        try profileData.write(to: URL(fileURLWithPath: profilePath))
    }
    
    private func generateCSR() -> String {
        return Data((0..<256).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
    }
    
    enum SigningError: LocalizedError {
        case invalidSession
        case certificateFetchFailed
        case teamFetchFailed
        case bundleIdFailed
        case profileFetchFailed
        case appPathNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidSession: return "Сессия недействительна"
            case .certificateFetchFailed: return "Не удалось получить сертификат"
            case .teamFetchFailed: return "Не удалось получить Team ID"
            case .bundleIdFailed: return "Не удалось зарегистрировать Bundle ID"
            case .profileFetchFailed: return "Не удалось получить профиль"
            case .appPathNotFound: return "Путь к приложению не найден"
            }
        }
    }
}