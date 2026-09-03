import Foundation
import CryptoKit

class AppleAuthService {
    static let shared = AppleAuthService()
    
    private let gsaURL = "https://gsa.apple.com/grandslam/GsService2"
    private let urlSession = URLSession(configuration: .default)
    
    func authenticate(email: String, password: String) async throws -> AppleIDCredentials {
        let srpResult = try await performSRPAuth(email: email, password: password)
        
        var credentials = AppleIDCredentials(email: email, password: password)
        credentials.session = AppleIDCredentials.AppleSession(
            dsid: srpResult.dsid,
            adsid: srpResult.adsid,
            token: srpResult.token,
            expiration: Date().addingTimeInterval(60 * 60 * 24 * 7)
        )
        
        CredentialsStore.shared.save(credentials)
        return credentials
    }
    
    private struct SRPResult {
        let dsid: String
        let adsid: String
        let token: String
    }
    
    private func performSRPAuth(email: String, password: String) async throws -> SRPResult {
        let clientSRP = try await initSRPHandshake(email: email)
        let serverResponse = try await sendSRPInit(email: email, clientPublicKey: clientSRP.publicKey)
        let proof = try computeSRPProof(
            email: email,
            password: password,
            salt: serverResponse.salt,
            serverPublicKey: serverResponse.publicKey,
            clientPrivateKey: clientSRP.privateKey
        )
        let authResult = try await sendSRPProof(
            email: email,
            proof: proof,
            srpSession: serverResponse.session
        )
        return authResult
    }
    
    private struct ClientSRPKeys {
        let publicKey: Data
        let privateKey: Data
    }
    
    private struct ServerSRPResponse {
        let salt: Data
        let publicKey: Data
        let session: String
    }
    
    private func initSRPHandshake(email: String) async throws -> ClientSRPKeys {
        var privateKeyBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &privateKeyBytes)
        let privateKey = Data(privateKeyBytes)
        let publicKey = Data(privateKeyBytes.prefix(32))
        return ClientSRPKeys(publicKey: publicKey, privateKey: privateKey)
    }
    
    private func sendSRPInit(email: String, clientPublicKey: Data) async throws -> ServerSRPResponse {
        var request = URLRequest(url: URL(string: gsaURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-apple-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("akd/1.0 AppRenewer/1.0", forHTTPHeaderField: "User-Agent")
        
        let body: [String: Any] = [
            "A2k": clientPublicKey.base64EncodedString(),
            "ps": ["s2k", "s2k_fo"],
            "u": email,
            "o": "init"
        ]
        
        request.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        
        let (data, _) = try await urlSession.data(for: request)
        guard let response = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let saltB64 = response["s"] as? String,
              let serverPublicKeyB64 = response["B"] as? String,
              let srpSession = response["c"] as? String,
              let saltData = Data(base64Encoded: saltB64),
              let serverPublicKey = Data(base64Encoded: serverPublicKeyB64)
        else {
            throw AuthError.invalidResponse
        }
        
        return ServerSRPResponse(salt: saltData, publicKey: serverPublicKey, session: srpSession)
    }
    
    private func computeSRPProof(
        email: String,
        password: String,
        salt: Data,
        serverPublicKey: Data,
        clientPrivateKey: Data
    ) throws -> Data {
        let passwordData = Data(password.utf8)
        let saltedPassword = salt + passwordData
        let hash = SHA256.hash(data: saltedPassword)
        return Data(hash)
    }
    
    private func sendSRPProof(email: String, proof: Data, srpSession: String) async throws -> SRPResult {
        var request = URLRequest(url: URL(string: gsaURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-apple-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("akd/1.0 AppRenewer/1.0", forHTTPHeaderField: "User-Agent")
        
        let body: [String: Any] = [
            "M1": proof.base64EncodedString(),
            "c": srpSession,
            "u": email,
            "o": "complete"
        ]
        
        request.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        
        let (data, _) = try await urlSession.data(for: request)
        guard let response = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let status = response["Status"] as? [String: Any],
              let ec = status["ec"] as? Int, ec == 0,
              let dsid = response["AppleUserID"] as? String,
              let adsid = response["adsid"] as? String,
              let tokenDict = response["GsIdmsToken"] as? [String: Any],
              let token = tokenDict["u"] as? String
        else {
            throw AuthError.authFailed
        }
        
        return SRPResult(dsid: dsid, adsid: adsid, token: token)
    }
    
    func validateSession(_ session: AppleIDCredentials.AppleSession) -> Bool {
        return session.isValid
    }
    
    enum AuthError: LocalizedError {
        case invalidResponse
        case authFailed
        case sessionExpired
        case twoFactorRequired
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Неверный ответ от Apple"
            case .authFailed: return "Ошибка авторизации. Проверь Apple ID и пароль"
            case .sessionExpired: return "Сессия истекла, войди снова"
            case .twoFactorRequired: return "Требуется двухфакторная аутентификация"
            }
        }
    }
}