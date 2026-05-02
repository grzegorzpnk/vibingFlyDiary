import Foundation
import AuthenticationServices
import Observation
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

@Observable
final class AuthService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    // MARK: - State

    private(set) var isAuthenticated = false
    private(set) var userProfile: UserProfile?

    // Stored during Apple Sign-In request so completion can use it
    private var currentNonce: String?

    // MARK: - Keychain keys

    private enum KeychainKey {
        static let userID = "flightDiary.apple.userID"
        static let name   = "flightDiary.apple.name"
        static let email  = "flightDiary.apple.email"
    }

    // MARK: - Init

    override init() {
        super.init()

        // Mirror Firebase auth state → isAuthenticated
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            DispatchQueue.main.async {
                if let user {
                    // Keep any richer profile we already resolved; fall back to Firebase values
                    if self.userProfile == nil {
                        self.userProfile = UserProfile(
                            id: user.uid,
                            displayName: user.displayName ?? "Traveler",
                            email: user.email
                        )
                    }
                    self.isAuthenticated = true
                } else {
                    self.isAuthenticated = false
                    self.userProfile = nil
                }
            }
        }

        restoreSession()
    }

    // MARK: - Session restore

    func restoreSession() {
        // Firebase already has a cached session — nothing more needed
        if Auth.auth().currentUser != nil { return }

        // Check if Apple previously confirmed this device
        guard let userID = keychainRead(key: KeychainKey.userID) else { return }
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .authorized:
                    // Firebase token can't be silently refreshed — show sign-in again
                    // Keep UI in signed-out state so user re-authenticates and gets Firebase UID
                    break
                case .revoked, .notFound:
                    self.clearKeychain()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Apple Sign-In

    /// Programmatically starts the Sign in with Apple flow via ASAuthorizationController.
    func startAppleSignIn() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func handleAuthorization(_ authorization: ASAuthorization) {
        guard
            let credential  = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce       = currentNonce,
            let tokenData   = credential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else { return }

        let firstName   = credential.fullName?.givenName  ?? ""
        let lastName    = credential.fullName?.familyName ?? ""
        let name        = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        let displayName = name.isEmpty ? "Traveler" : name
        let email       = credential.email

        // Persist Apple user ID in case Firebase session expires
        keychainWrite(key: KeychainKey.userID, value: credential.user)
        keychainWrite(key: KeychainKey.name,   value: displayName)
        if let email { keychainWrite(key: KeychainKey.email, value: email) }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        signInToFirebase(with: firebaseCredential, displayName: displayName, email: email)
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            guard let self, error == nil, let result else { return }
            guard let idToken = result.user.idToken?.tokenString else { return }
            let accessToken = result.user.accessToken.tokenString
            let displayName = result.user.profile?.name ?? "Traveler"
            let email       = result.user.profile?.email

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            self.signInToFirebase(with: credential, displayName: displayName, email: email)
        }
    }

    // MARK: - Guest

    func continueAsGuest() {
        guard Auth.auth().currentUser == nil else {
            isAuthenticated = true
            return
        }
        Auth.auth().signInAnonymously { _, error in
            if let error { print("[Auth] Anonymous sign-in failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        clearKeychain()
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        // isAuthenticated updated by the Firebase auth state listener
    }

    // MARK: - Private: Firebase sign-in

    /// Signs into Firebase, linking anonymous data if the current user is anonymous.
    private func signInToFirebase(with credential: AuthCredential, displayName: String, email: String?) {
        if let anon = Auth.auth().currentUser, anon.isAnonymous {
            // Preserve anonymous flights by linking instead of creating a new account
            anon.link(with: credential) { [weak self] result, error in
                if let result {
                    self?.finishSignIn(user: result.user, displayName: displayName, email: email)
                } else {
                    // Credential already belongs to an existing account — sign in normally
                    Auth.auth().signIn(with: credential) { [weak self] result, _ in
                        if let result { self?.finishSignIn(user: result.user, displayName: displayName, email: email) }
                    }
                }
            }
        } else {
            Auth.auth().signIn(with: credential) { [weak self] result, _ in
                if let result { self?.finishSignIn(user: result.user, displayName: displayName, email: email) }
            }
        }
    }

    private func finishSignIn(user: FirebaseAuth.User, displayName: String, email: String?) {
        DispatchQueue.main.async {
            self.userProfile = UserProfile(id: user.uid, displayName: displayName, email: email ?? user.email)
            self.isAuthenticated = true
        }
        // Sync display name to Firebase profile if missing
        if (user.displayName ?? "").isEmpty {
            let req = user.createProfileChangeRequest()
            req.displayName = displayName
            req.commitChanges(completion: nil)
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleAuthorization(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("[Apple] Sign-in error: \(error.localizedDescription)")
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? ASPresentationAnchor()
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            randoms.forEach { byte in
                guard remaining > 0 else { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain helpers

    private func keychainWrite(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
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
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func clearKeychain() {
        [KeychainKey.userID, KeychainKey.name, KeychainKey.email].forEach { key in
            let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
            SecItemDelete(query as CFDictionary)
        }
    }
}
