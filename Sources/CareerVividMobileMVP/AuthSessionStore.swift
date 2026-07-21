import Foundation

@MainActor
final class AuthSessionStore: ObservableObject {
    enum AuthAction {
        case signIn
        case createAccount
    }

    @Published private(set) var session: CVFirebaseSession?
    @Published private(set) var isLoading = true
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let guestAcceptedKey = "cv_guest_accepted_v1"

    /// Persisted so a returning guest goes straight into the app instead of
    /// re-tapping "Continue as guest" on every launch. Cleared on sign out and
    /// account deletion.
    private var acceptedGuestForLaunch = false {
        didSet { UserDefaults.standard.set(acceptedGuestForLaunch, forKey: guestAcceptedKey) }
    }

    var shouldShowAuthGate: Bool {
        if isLoading { return false }
        guard let session else { return true }
        return session.isAnonymous && !acceptedGuestForLaunch
    }

    var displayName: String {
        if let email = session?.email, !email.isEmpty {
            return email
        }
        return session?.isAnonymous == true ? "Guest session" : "Vivid"
    }

    func load() async {
        isLoading = true
        acceptedGuestForLaunch = UserDefaults.standard.bool(forKey: guestAcceptedKey)
        session = await CVFirebaseAuth.shared.currentSession()
        isLoading = false
    }

    func continueAsGuest() async {
        await submitSession(acceptGuest: true) {
            try await CVFirebaseAuth.shared.continueAnonymously()
        }
    }

    func signIn(email: String, password: String) async {
        await submitSession(acceptGuest: false) {
            try await CVFirebaseAuth.shared.signInWithEmail(email: email, password: password)
        }
    }

    func createAccount(email: String, password: String) async {
        await submitSession(acceptGuest: false) {
            try await CVFirebaseAuth.shared.createEmailAccount(email: email, password: password)
        }
    }

    func signInWithGoogle() async {
        await submitSession(acceptGuest: false) {
            let credential = try await GoogleSignInService.shared.signIn()
            return try await CVFirebaseAuth.shared.signInWithGoogle(
                idToken: credential.idToken,
                accessToken: credential.accessToken
            )
        }
    }

    func signOut() async {
        await CVFirebaseAuth.shared.signOut()
        acceptedGuestForLaunch = false
        session = nil
    }

    /// Permanently deletes the account on Firebase, then wipes every local trace
    /// (reports, skill profile, challenge progress) and returns to the auth gate.
    /// Throws so the caller can surface a failure instead of silently signing out.
    func deleteAccount() async throws {
        try await CVFirebaseAuth.shared.deleteAccount()
        LocalInterviewReportCache.clear()
        InterviewSkillProfileStore.clear()
        SkillTreeChallengeProgressStore.clear()
        acceptedGuestForLaunch = false
        session = nil
    }

    private func submitSession(
        acceptGuest: Bool,
        _ operation: @escaping () async throws -> CVFirebaseSession
    ) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let nextSession = try await operation()
            acceptedGuestForLaunch = acceptGuest
            session = nextSession
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
