import SwiftUI

struct StatsView: View {
    @Environment(LocalizationService.self) private var ls

    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(FDColor.gold.opacity(0.5))
                Text(ls.tabStats)
                    .font(FDFont.display(22, weight: .bold))
                    .foregroundStyle(FDColor.text)
                Text(ls.statsComingSoon)
                    .font(FDFont.ui(13))
                    .foregroundStyle(FDColor.textMuted)
            }
        }
    }
}
