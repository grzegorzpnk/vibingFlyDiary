import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store
    @Environment(LocalizationService.self) private var ls

    private var features: [(icon: String, text: String)] {[
        ("infinity",            ls.premiumFeatureUnlimited),
        ("icloud.fill",         ls.premiumFeatureSync),
        ("chart.bar.fill",      ls.premiumFeatureStats),
        ("square.and.arrow.up", ls.premiumFeatureShare),
        ("star.fill",           ls.premiumFeatureSupport)
    ]}

    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(FDColor.textMuted)
                                .frame(width: 32, height: 32)
                                .background(FDColor.surface2)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Hero
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(FDColor.gold.opacity(0.12))
                                .frame(width: 100, height: 100)
                            Circle()
                                .fill(FDColor.gold.opacity(0.06))
                                .frame(width: 130, height: 130)
                            Image(systemName: "airplane.circle.fill")
                                .font(.system(size: 56, weight: .light))
                                .foregroundStyle(FDColor.gold)
                        }
                        .padding(.top, 12)

                        VStack(spacing: 8) {
                            Text("✦ FLOWN")
                                .font(FDFont.ui(11, weight: .medium))
                                .foregroundStyle(FDColor.gold)
                                .tracking(3)
                            Text("Premium")
                                .font(FDFont.display(36, weight: .bold))
                                .foregroundStyle(FDColor.text)
                            Text(ls.premiumUnlockDesc)
                                .font(FDFont.ui(15))
                                .foregroundStyle(FDColor.textMuted)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.bottom, 36)

                    // Features list
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            if index > 0 {
                                Rectangle()
                                    .fill(FDColor.border)
                                    .frame(height: 0.5)
                                    .padding(.leading, 52)
                            }
                            HStack(spacing: 16) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(FDColor.gold)
                                    .frame(width: 28)
                                Text(feature.text)
                                    .font(FDFont.ui(15))
                                    .foregroundStyle(FDColor.text)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(FDColor.gold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                    .background(FDColor.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FDColor.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                    // Free tier note
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                        Text(String(format: ls.premiumFreeTier, StoreService.freeFlightLimit))
                            .font(FDFont.ui(12))
                    }
                    .foregroundStyle(FDColor.textDim)
                    .padding(.bottom, 24)

                    // Price + CTA
                    VStack(spacing: 12) {
                        if let product = store.monthlyProduct {
                            Text("\(product.displayPrice) \(ls.premiumPerMonth)")
                                .font(FDFont.display(22, weight: .bold))
                                .foregroundStyle(FDColor.text)
                        }

                        Button {
                            Task { await store.purchase() }
                        } label: {
                            ZStack {
                                if store.isLoading {
                                    ProgressView()
                                        .tint(FDColor.black)
                                } else {
                                    Text(store.monthlyProduct != nil ? ls.subscribeNow : ls.premiumLoading)
                                        .font(FDFont.ui(16, weight: .bold))
                                        .tracking(0.3)
                                        .foregroundStyle(FDColor.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(store.monthlyProduct != nil ? FDColor.gold : FDColor.gold.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(store.monthlyProduct == nil || store.isLoading)

                        Button {
                            Task { await store.restore() }
                        } label: {
                            Text(ls.restorePurchases)
                                .font(FDFont.ui(13))
                                .foregroundStyle(FDColor.textMuted)
                                .underline()
                        }
                        .disabled(store.isLoading)
                    }
                    .padding(.horizontal, 20)

                    if let error = store.purchaseError {
                        Text(error)
                            .font(FDFont.ui(12))
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    Text(ls.premiumRenewalNote)
                        .font(FDFont.ui(11))
                        .foregroundStyle(FDColor.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(ls.preferredColorScheme)
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }
}
