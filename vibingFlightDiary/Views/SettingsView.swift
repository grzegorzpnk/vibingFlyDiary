import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FDColor.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // App identity header
                        VStack(spacing: 6) {
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(FDColor.gold)
                            Text("Flygram")
                                .font(FDFont.display(22, weight: .bold))
                                .foregroundStyle(FDColor.text)
                            Text("v\(appVersion)")
                                .font(FDFont.ui(12))
                                .foregroundStyle(FDColor.textDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        // Account section
                        settingsSection(title: "ACCOUNT") {
                            settingsRow(icon: "person.fill", label: "Profile") {
                                comingSoonBadge
                            }
                            settingsDivider
                            settingsRow(icon: "icloud.fill", label: "Sync & Backup") {
                                comingSoonBadge
                            }
                        }

                        // Appearance section
                        settingsSection(title: "APPEARANCE") {
                            settingsRow(icon: "circle.lefthalf.filled", label: "Theme") {
                                comingSoonBadge
                            }
                            settingsDivider
                            settingsRow(icon: "globe", label: "Units") {
                                comingSoonBadge
                            }
                        }

                        // About section
                        settingsSection(title: "ABOUT") {
                            settingsRow(icon: "info.circle.fill", label: "Version") {
                                Text(appVersion)
                                    .font(FDFont.ui(13))
                                    .foregroundStyle(FDColor.textMuted)
                            }
                            settingsDivider
                            settingsRow(icon: "heart.fill", label: "Made with passion") {
                                EmptyView()
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(FDFont.ui(15, weight: .medium))
                        .foregroundStyle(FDColor.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(FDFont.ui(14, weight: .medium))
                        .foregroundStyle(FDColor.gold)
                }
            }
            .toolbarBackground(FDColor.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationBackground(FDColor.black)
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(FDFont.ui(11, weight: .medium))
                .foregroundStyle(FDColor.textMuted)
                .tracking(1.5)
                .padding(.bottom, 10)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(FDColor.surface2)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FDColor.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func settingsRow<Trailing: View>(icon: String, label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FDColor.gold)
                .frame(width: 24)
            Text(label)
                .font(FDFont.ui(14))
                .foregroundStyle(FDColor.text)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(FDColor.border)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private var comingSoonBadge: some View {
        Text("Soon")
            .font(FDFont.ui(10, weight: .medium))
            .foregroundStyle(FDColor.textDim)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(FDColor.surface3)
            .clipShape(Capsule())
    }
}
