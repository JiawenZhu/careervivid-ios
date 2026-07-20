import SwiftUI
import StoreKit

// MARK: - Support constants

private enum SettingsLinks {
    static let supportEmail = "support@careervivid.app"
    static let privacyURL = URL(string: "https://careervivid.app/privacy")!
    static let termsURL = URL(string: "https://careervivid.app/terms")!

    static var mailURL: URL {
        let subject = "Vivid Support"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(supportEmail)?subject=\(encoded)")!
    }
}

// MARK: - Gear button (used on the home header)

struct SettingsGearButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: {
            cvImpactHaptic(.light)
            action()
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.cvInk)
                .frame(width: 44, height: 44)
                .background(Color.cvSurface, in: Circle())
                .overlay(Circle().stroke(Color.cvCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

// MARK: - Settings screen

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @State private var showAuth = false
    @State private var showLegal = false
    @State private var showWhatsNew = false
    @State private var comingSoon: ComingSoonKind?
    @State private var confirmLogout = false
    @State private var confirmDelete = false

    private var isSignedIn: Bool {
        guard let session = authStore.session else { return false }
        return !session.isAnonymous && (session.email?.isEmpty == false)
    }

    private var accountEmail: String { authStore.session?.email ?? "" }

    private var versionText: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    accountSection
                    aboutSection
                    dangerSection
                    versionFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.cvSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        cvImpactHaptic(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.cvInkSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color.cvSurface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
        }
        .sheet(isPresented: $showAuth) { AuthSheet() }
        .sheet(isPresented: $showLegal) { LegalSheet() }
        .sheet(isPresented: $showWhatsNew) { WhatsNewSheet(version: versionText) }
        .sheet(item: $comingSoon) { kind in ComingSoonSheet(kind: kind) }
        .confirmationDialog("Log out of Vivid?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                Task { await authStore.signOut(); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete account?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task { await authStore.signOut(); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your Vivid account and signs you out on this device. This cannot be undone.")
        }
    }

    // MARK: Sections

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsSectionHeader("Account")

            if isSignedIn {
                SettingsRow(
                    emoji: "👤",
                    title: accountEmail,
                    subtitle: "Vivid account"
                ) { showAuth = true }
            } else {
                SettingsRow(
                    emoji: "☁️",
                    title: "Register / Log in",
                    subtitle: "Sync your reports across devices"
                ) { showAuth = true }
            }

            SettingsRow(
                emoji: "💎",
                title: "Go Premium",
                subtitle: "Unlock unlimited practice and coaching"
            ) { comingSoon = .premium }

            SettingsRow(
                emoji: "🔄",
                title: "Restore Purchases",
                subtitle: "Already premium? Restore it here"
            ) { comingSoon = .restore }

            if isSignedIn {
                SettingsRow(
                    emoji: "🚪",
                    title: "Log out",
                    subtitle: "Sign out of this device",
                    tint: Color.cvQuestionDanger
                ) { confirmLogout = true }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsSectionHeader("About & Support")

            SettingsRow(
                emoji: "🆕",
                title: "What's new",
                subtitle: versionText
            ) { showWhatsNew = true }

            SettingsRow(
                emoji: "⭐️",
                title: "Do you like Vivid?",
                subtitle: "Would you mind leaving a review?"
            ) { requestReview() }

            SettingsRow(
                emoji: "✉️",
                title: "Any issues?",
                subtitle: "Email us at \(SettingsLinks.supportEmail)"
            ) { openURL(SettingsLinks.mailURL) }

            SettingsRow(
                emoji: "📕",
                title: "Legal",
                subtitle: "Privacy policy and terms of service"
            ) { showLegal = true }
        }
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsSectionHeader("Account management")

            SettingsRow(
                emoji: "🗑️",
                title: "Delete account",
                subtitle: "Permanently delete your Vivid account",
                tint: Color.cvQuestionDanger
            ) { confirmDelete = true }
        }
    }

    private var versionFooter: some View {
        Text("Vivid v\(versionText)")
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.cvInkTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
    }
}

// MARK: - Row & section header

private struct SettingsSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.cvInkTertiary)
            .padding(.horizontal, 4)
            .padding(.top, 22)
            .padding(.bottom, 4)
    }
}

private struct SettingsRow: View {
    let emoji: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = Color.cvInk
    let action: () -> Void

    var body: some View {
        Button(action: {
            cvImpactHaptic(.light)
            action()
        }) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 22))
                    .frame(width: 46, height: 46)
                    .background(Color.cvSurface, in: Circle())
                    .overlay(Circle().stroke(Color.cvCardBorder, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.cvInkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cvInkTertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sub-sheets

private struct AuthSheet: View {
    @EnvironmentObject private var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AuthView(store: authStore)
            .onChange(of: authStore.session) { _, session in
                // Dismiss once a real (non-anonymous) session lands.
                if let session, !session.isAnonymous {
                    dismiss()
                }
            }
    }
}

private struct LegalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    SettingsRowLite(emoji: "🔒", title: "Privacy Policy") {
                        openURL(SettingsLinks.privacyURL)
                    }
                    SettingsRowLite(emoji: "📄", title: "Terms of Service") {
                        openURL(SettingsLinks.termsURL)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color.cvSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SettingsRowLite: View {
    let emoji: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(Color.cvSurface, in: Circle())
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.cvInk)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cvInkTertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WhatsNewSheet: View {
    let version: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Version \(version)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.cvInk)
                    whatsNewItem("🎙️", "Interview practice with instant reports")
                    whatsNewItem("📄", "Resume coach that turns notes into drafts")
                    whatsNewItem("⚙️", "New Settings screen — account, premium, and support")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color.cvSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle("What's new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func whatsNewItem(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 20))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.cvInkSecondary)
        }
    }
}

enum ComingSoonKind: String, Identifiable {
    case premium, restore
    var id: String { rawValue }

    var emoji: String { self == .premium ? "💎" : "🔄" }
    var title: String { self == .premium ? "Go Premium" : "Restore Purchases" }
    var message: String {
        switch self {
        case .premium:
            return "Premium unlocks unlimited practice and deeper coaching. In-app purchases are coming soon — thanks for your patience!"
        case .restore:
            return "Purchase restore will be available once Premium launches."
        }
    }
}

private struct ComingSoonSheet: View {
    let kind: ComingSoonKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text(kind.emoji).font(.system(size: 52))
            Text(kind.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.cvInk)
            Text(kind.message)
                .font(.subheadline)
                .foregroundStyle(Color.cvInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.cvBrandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(Color.cvSystemGroupedBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
