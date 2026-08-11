import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class GmailOAuthClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var currentSession: ASWebAuthenticationSession?
    private let tokenStore = GmailTokenStore()

    func accessToken() async throws -> String {
        if let token = tokenStore.load(), token.expiresAt > Date.now.addingTimeInterval(60) {
            return token.accessToken
        }

        let configuration = try Configuration.fromBundle()
        let verifier = try randomURLSafeString(byteCount: 48)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString
        let state = try randomURLSafeString(byteCount: 24)
        let code = try await authorizationCode(
            configuration: configuration,
            codeChallenge: challenge,
            state: state
        )
        let token = try await exchangeCode(
            code,
            verifier: verifier,
            configuration: configuration
        )
        tokenStore.save(token)
        return token.accessToken
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor(frame: .zero)
    }

    private func authorizationCode(
        configuration: Configuration,
        codeChallenge: String,
        state: String
    ) async throws -> String {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: gmailReadonlyScope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "include_granted_scopes", value: "true")
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: configuration.callbackScheme
            ) { [self] callbackURL, error in
                currentSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value == state,
                      let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GmailOAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            currentSession = session
            if !session.start() {
                currentSession = nil
                continuation.resume(throwing: GmailOAuthError.couldNotStart)
            }
        }
    }

    private func exchangeCode(
        _ code: String,
        verifier: String,
        configuration: Configuration
    ) async throws -> GmailOAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = [
            "client_id": configuration.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": configuration.redirectURI
        ].formURLEncodedData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GmailOAuthError.tokenExchangeFailed
        }

        let responseToken = try JSONDecoder().decode(GmailTokenResponse.self, from: data)
        return GmailOAuthToken(
            accessToken: responseToken.accessToken,
            expiresAt: Date.now.addingTimeInterval(TimeInterval(responseToken.expiresIn))
        )
    }

    private func randomURLSafeString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else { throw GmailOAuthError.randomGenerationFailed }
        return Data(bytes).base64URLEncodedString
    }

    private struct Configuration {
        let clientID: String
        let callbackScheme: String

        var redirectURI: String { "\(callbackScheme):/oauthredirect" }

        static func fromBundle() throws -> Configuration {
            guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GmailOAuthClientID") as? String,
                  let callbackScheme = Bundle.main.object(forInfoDictionaryKey: "GmailOAuthCallbackScheme") as? String,
                  !clientID.contains("REPLACE_ME"),
                  !callbackScheme.contains("REPLACE_ME") else {
                throw GmailOAuthError.missingConfiguration
            }
            return Configuration(clientID: clientID, callbackScheme: callbackScheme)
        }
    }

    private let gmailReadonlyScope = "https://www.googleapis.com/auth/gmail.readonly"
}

private struct GmailTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct GmailOAuthToken: Codable {
    let accessToken: String
    let expiresAt: Date
}

private struct GmailTokenStore {
    private let service = "com.dongdaemoontwin.ReturnTracker.gmail"
    private let account = "oauth-access-token"

    func load() -> GmailOAuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(GmailOAuthToken.self, from: data)
    }

    func save(_ token: GmailOAuthToken) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}

private enum GmailOAuthError: LocalizedError {
    case missingConfiguration
    case invalidCallback
    case couldNotStart
    case tokenExchangeFailed
    case randomGenerationFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "iOS Gmail OAuth 클라이언트 ID가 아직 설정되지 않았습니다."
        case .invalidCallback:
            "Google 로그인 응답을 확인할 수 없습니다."
        case .couldNotStart:
            "Google 로그인 화면을 열 수 없습니다."
        case .tokenExchangeFailed:
            "Gmail 접근 토큰을 받을 수 없습니다."
        case .randomGenerationFailed:
            "보안 인증값을 만들 수 없습니다."
        }
    }
}

private extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension Dictionary where Key == String, Value == String {
    var formURLEncodedData: Data? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let body = sorted { $0.key < $1.key }.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
        return body.data(using: .utf8)
    }
}
