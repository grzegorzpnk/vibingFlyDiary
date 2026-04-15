import SwiftUI

struct StatsView: View {
    var body: some View {
        ZStack {
            FDColor.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(FDColor.gold.opacity(0.5))
                Text("Stats")
                    .font(FDFont.display(22, weight: .bold))
                    .foregroundStyle(FDColor.text)
                Text("Coming soon")
                    .font(FDFont.ui(13))
                    .foregroundStyle(FDColor.textMuted)
            }
        }
    }
}
