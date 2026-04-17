import Foundation
import AuthenticationServices
import Observation

@Observable
final class AuthService: NSObject {

    // MARK: - State

    private(set) var isAuthenticated = false
    private(set) var userProfile: UserProfile?

    // MARK: - Keychain keys

    private enum KeychainKey {
        static let userID   = "flightDiary.apple.userID"
        static let name     = "flightDiary.apple.name"
        static let email    = "flightDiary.apple.email"
    }

    // MARK: - Init

    override init() {
        super.init()
        restoreSession()
    }

    // MARK: - Session restore

    /// Checks locally whether Apple has revoked the credential.
    /// No network call — handled by the OS via AuthenticationServices.
    func restoreSession() {
        guard let userID = keychainRead(key: KeychainKey.userID) else { return }
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .authorized:
                    let name  = self.keychainRead(key: KeychainKey.name)  ?? "Traveler"
                    let email = self.keychainRead(key: KeychainKey.email)
                    self.userProfile = UserProfile(id: userID, displayName: name, email: email)
                    self.isAuthenticated = true
                case .revoked, .notFound:
                    self.clearKeychain()
                    self.isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    // MARK: - Sign In

    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let userID    = credential.user
        let firstName = credential.fullName?.givenName ?? ""
        let lastName  = credential.fullName?.familyName ?? ""
        let name      = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        let email     = credential.email
        let displayName = name.isEmpty ? "Traveler" : name

        keychainWrite(key: KeychainKey.userID, value: userID)
        keychainWrite(key: KeychainKey.name, value: displayName)
        if let email { keychainWrite(key: KeychainKey.email, value: email) }

        userProfile = UserProfile(id: userID, displayName: displayName, email: email)
        isAuthenticated = true
    }

    // MARK: - Guest

    func continueAsGuest() {
        userProfile = nil
        isAuthenticated = true
    }

    // MARK: - Sign Out

    func signOut() {
        clearKeychain()
        userProfile = nil
        isAuthenticated = false
    }

    // MARK: - Keychain helpers

    private func keychainWrite(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
        let attrs: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func keychainRead(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func clearKeychain() {
        [KeychainKey.userID, KeychainKey.name, KeychainKey.email].forEach { key in
            let query: [CFString: Any] = [
                kSecClass:       kSecClassGenericPassword,
                kSecAttrAccount: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
