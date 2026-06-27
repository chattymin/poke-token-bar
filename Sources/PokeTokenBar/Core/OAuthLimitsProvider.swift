import Foundation
import Security

enum LimitsError: Error {
    case keychainAccessDisabled
    case keychainUnavailable(OSStatus)
    case keychainInteractionNotAllowed
    case credentialFormat
    case httpStatus(Int)
}

/// Claude 한도 조회 추상화 — 실 구현(OAuthLimitsProvider) 또는 테스트 스텁 주입.
protocol ClaudeLimitsProviding: Sendable {
    func fetch(allowKeychainPrompt: Bool) async throws -> LimitStatus
}

/// 공식 한도 % 조회 — Claude Code 자격증명(Keychain)의 OAuth 토큰으로 usage endpoint 호출.
/// 비공식 endpoint 이므로 실패해도 토큰 표시에는 영향 없음 (한도 섹션만 숨김).
struct OAuthLimitsProvider: ClaudeLimitsProviding, Sendable {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let accessTokenCache = OAuthAccessTokenCache.shared

    func fetch(allowKeychainPrompt: Bool = false) async throws -> LimitStatus {
        let token = try await accessTokenCache.accessToken(allowKeychainPrompt: allowKeychainPrompt)
        do {
            return try await fetchStatus(accessToken: token)
        } catch let error as LimitsError {
            guard case .httpStatus(let status) = error, status == 401 || status == 403 else {
                throw error
            }
            await accessTokenCache.invalidate(removePersistentCache: true)
            let refreshed = try await accessTokenCache.accessToken(
                allowKeychainPrompt: allowKeychainPrompt, bypassCache: true)
            guard refreshed != token else { throw error }
            return try await fetchStatus(accessToken: refreshed)
        }
    }

    private func fetchStatus(accessToken: String) async throws -> LimitStatus {
        var request = URLRequest(url: Self.usageURL, timeoutInterval: 15)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw LimitsError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(LimitStatus.self, from: data)
    }
}

private actor OAuthAccessTokenCache {
    static let shared = OAuthAccessTokenCache()
    private var cachedCredential: OAuthCredentialData.Credential?

    func accessToken(allowKeychainPrompt: Bool, bypassCache: Bool = false) throws -> String {
        if !bypassCache, let cachedCredential, !cachedCredential.isExpired {
            return cachedCredential.accessToken
        }

        if let credential = try Self.readPokeTokenBarCache() {
            cachedCredential = credential
            return credential.accessToken
        }
        if let credential = try Self.readClaudeCredentialsFile() {
            cachedCredential = credential
            Self.writePokeTokenBarCache(credential.data)
            return credential.accessToken
        }
        // Claude Keychain 항목은 앱 직접 read 단일 경로로만 읽는다(프롬프트 1회).
        // 과거의 `security` CLI 보조 경로는 별도 신원이라 같은 항목에 두 번째 ACL 프롬프트를
        // 띄웠고(1.5s 타임아웃도 대화형에 부적합) 제거함. 최초 1회 허용 후 앱 자체 Keychain
        // 캐시(writePokeTokenBarCache)에 저장돼 이후 재프롬프트 없음.
        guard allowKeychainPrompt else {
            throw LimitsError.keychainInteractionNotAllowed
        }

        let credential = try Self.readClaudeKeychain(allowKeychainPrompt: allowKeychainPrompt)
        cachedCredential = credential
        Self.writePokeTokenBarCache(credential.data)
        return credential.accessToken
    }

    func invalidate(removePersistentCache: Bool = false) {
        cachedCredential = nil
        if removePersistentCache {
            Self.deletePokeTokenBarCache()
        }
    }

    private nonisolated static func readPokeTokenBarCache() throws -> OAuthCredentialData.Credential? {
        if KeychainAccessGate.isDisabled {
            throw LimitsError.keychainAccessDisabled
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: OAuthCredentialData.tokenMacCacheService,
            kSecAttrAccount as String: OAuthCredentialData.tokenMacCacheAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        KeychainNoUIQuery.apply(to: &query)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            guard let credential = OAuthCredentialData.credential(from: data), !credential.isExpired else {
                deletePokeTokenBarCache()
                return nil
            }
            return credential
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed:
            throw LimitsError.keychainInteractionNotAllowed
        default:
            throw LimitsError.keychainUnavailable(status)
        }
    }

    private nonisolated static func writePokeTokenBarCache(_ data: Data) {
        if KeychainAccessGate.isDisabled { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: OAuthCredentialData.tokenMacCacheService,
            kSecAttrAccount as String: OAuthCredentialData.tokenMacCacheAccount,
        ]
        KeychainNoUIQuery.apply(to: &query)

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            AppLog.write("oauth cache update failed: \(updateStatus)")
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrLabel as String] = "PokeTokenBar OAuth Cache"
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            AppLog.write("oauth cache add failed: \(addStatus)")
        }
    }

    private nonisolated static func deletePokeTokenBarCache() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: OAuthCredentialData.tokenMacCacheService,
            kSecAttrAccount as String: OAuthCredentialData.tokenMacCacheAccount,
        ]
        KeychainNoUIQuery.apply(to: &query)
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            AppLog.write("oauth cache delete failed: \(status)")
        }
    }

    private nonisolated static func readClaudeCredentialsFile() throws -> OAuthCredentialData.Credential? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let credential = OAuthCredentialData.credential(from: data), !credential.isExpired else {
            return nil
        }
        return credential
    }

    private nonisolated static func readClaudeKeychain(
        allowKeychainPrompt: Bool) throws -> OAuthCredentialData.Credential
    {
        if KeychainAccessGate.isDisabled {
            throw LimitsError.keychainAccessDisabled
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: OAuthCredentialData.claudeKeychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if !allowKeychainPrompt {
            KeychainNoUIQuery.apply(to: &query)
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecInteractionNotAllowed {
            throw LimitsError.keychainInteractionNotAllowed
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw LimitsError.keychainUnavailable(status)
        }
        guard let credential = OAuthCredentialData.credential(from: data) else {
            throw LimitsError.credentialFormat
        }
        return credential
    }
}

enum OAuthCredentialData {
    static let claudeKeychainService = "Claude Code-credentials"
    static let tokenMacCacheService = "io.github.chattymin.poketokenbar.cache"
    static let tokenMacCacheAccount = "oauth.claude"

    struct Credential {
        let accessToken: String
        let expiresAt: Date?
        let data: Data

        var isExpired: Bool {
            guard let expiresAt else { return false }
            return expiresAt <= Date().addingTimeInterval(60)
        }
    }

    static func credential(from data: Data) -> Credential? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = json["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String, !token.isEmpty
        else {
            return nil
        }
        return Credential(accessToken: token, expiresAt: expiresAt(from: oauth["expiresAt"]), data: data)
    }

    private static func expiresAt(from raw: Any?) -> Date? {
        let value: Double?
        switch raw {
        case let raw as Double:
            value = raw
        case let raw as Int:
            value = Double(raw)
        case let raw as Int64:
            value = Double(raw)
        case let raw as String:
            value = Double(raw)
        default:
            value = nil
        }
        guard let value, value > 0 else { return nil }
        let seconds = value > 10_000_000_000 ? value / 1000 : value
        return Date(timeIntervalSince1970: seconds)
    }
}
