import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationService.self) private var ls

    @State private var languageExpanded = false

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

                        // Language section
                        settingsSection(title: ls.languageSection) {
                            // Collapsed row — tap to expand
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    languageExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(FDColor.gold)
                                        .frame(width: 24)
                                    Text(ls.languageSection)
                                        .font(FDFont.ui(14))
                                        .foregroundStyle(FDColor.text)
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Text(ls.language.flag)
                                            .font(.system(size: 16))
                                        Text(ls.language.displayName)
                                            .font(FDFont.ui(13))
                                            .foregroundStyle(FDColor.textMuted)
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(FDColor.textDim)
                                        .rotationEffect(.degrees(languageExpanded ? 180 : 0))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            // Expanded picker
                            if languageExpanded {
                                Rectangle()
                                    .fill(FDColor.border)
                                    .frame(height: 0.5)

                                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                                    if index > 0 {
                                        Rectangle()
                                            .fill(FDColor.border)
                                            .frame(height: 0.5)
                                            .padding(.leading, 54)
                                    }
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            ls.language = lang
                                            languageExpanded = false
                                        }
                                    } label: {
                                        HStack(spacing: 14) {
                                            Text(lang.flag)
                                                .font(.system(size: 18))
                                                .frame(width: 24)
                                            Text(lang.displayName)
                                                .font(FDFont.ui(14))
                                                .foregroundStyle(ls.language == lang ? FDColor.gold : FDColor.text)
                                            Spacer()
                                            if ls.language == lang {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(FDColor.gold)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(ls.language == lang ? FDColor.gold.opacity(0.05) : Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Account section
                        settingsSection(title: ls.accountSection) {
                            settingsRow(icon: "person.fill", label: ls.profileRow) {
                                comingSoonBadge
                            }
                            settingsDivider
                            settingsRow(icon: "icloud.fill", label: ls.syncRow) {
                                comingSoonBadge
                            }
                        }

                        // Appearance section
                        settingsSection(title: ls.appearanceSection) {
                            settingsRow(icon: "circle.lefthalf.filled", label: ls.themeRow) {
                                comingSoonBadge
                            }
                            settingsDivider
                            settingsRow(icon: "globe", label: ls.unitsRow) {
                                comingSoonBadge
                            }
                        }

                        // About section
                        settingsSection(title: ls.aboutSection) {
                            settingsRow(icon: "info.circle.fill", label: ls.versionRow) {
                                Text(appVersion)
                                    .font(FDFont.ui(13))
                                    .foregroundStyle(FDColor.textMuted)
                            }
                            settingsDivider
                            settingsRow(icon: "heart.fill", label: ls.madeWithPassion) {
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
                    Text(ls.settingsTitle)
                        .font(FDFont.ui(15, weight: .medium))
                        .foregroundStyle(FDColor.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(ls.doneButton) { dismiss() }
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
        Text(ls.comingSoon)
            .font(FDFont.ui(10, weight: .medium))
            .foregroundStyle(FDColor.textDim)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(FDColor.surface3)
            .clipShape(Capsule())
    }
}
