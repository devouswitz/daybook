import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Insights", systemImage: "chart.bar.fill")
                    .font(.title3.weight(.bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Stat tiles
            HStack(spacing: 10) {
                stat("\(store.entryCount)", "entries")
                stat("\(store.streak)", "day streak")
                stat("\(store.longestStreak)", "best streak")
                stat("\(store.entriesThisMonth)", "this month")
                stat(store.totalWords.formatted(), "words")
            }

            // Heatmap: trailing 15 weeks
            VStack(alignment: .leading, spacing: 6) {
                Text("Last 15 weeks").font(.subheadline.weight(.semibold))
                heatmap
                HStack(spacing: 4) {
                    Text("less").font(.caption2).foregroundStyle(.tertiary)
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(i))
                            .frame(width: 10, height: 10)
                    }
                    Text("more").font(.caption2).foregroundStyle(.tertiary)
                }
            }

            // Type breakdown
            if !store.countsByType.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("By type").font(.subheadline.weight(.semibold))
                    let maxCount = store.countsByType.map(\.count).max() ?? 1
                    ForEach(store.countsByType, id: \.type) { row in
                        HStack(spacing: 8) {
                            Image(systemName: row.type.icon)
                                .foregroundStyle(row.type.color)
                                .frame(width: 18)
                            Text(row.type.label)
                                .font(.callout)
                                .frame(width: 76, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(row.type.color.opacity(0.75))
                                    .frame(width: max(6, geo.size.width * CGFloat(row.count) / CGFloat(maxCount)))
                            }
                            .frame(height: 14)
                            Text("\(row.count)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
            }

            // Weekday rhythm
            VStack(alignment: .leading, spacing: 6) {
                Text("Weekday rhythm").font(.subheadline.weight(.semibold))
                let counts = store.countsByWeekday
                let maxC = max(counts.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.indigo.opacity(0.7))
                                .frame(width: 26, height: max(4, 52 * CGFloat(counts[i]) / CGFloat(maxC)))
                            Text(calendar.veryShortWeekdaySymbols[i])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 480, height: 560)
    }

    private var heatmap: some View {
        let days = store.dailyCounts(days: 15 * 7)
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        return HStack(alignment: .top, spacing: 3) {
            ForEach(0..<weeks.count, id: \.self) { w in
                VStack(spacing: 3) {
                    ForEach(0..<weeks[w].count, id: \.self) { d in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(min(weeks[w][d].count, 3)))
                            .frame(width: 10, height: 10)
                            .help("\(weeks[w][d].day.formatted(date: .abbreviated, time: .omitted)): \(weeks[w][d].count)")
                    }
                }
            }
        }
    }

    private func heatColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.primary.opacity(0.08)
        case 1: return Color.indigo.opacity(0.35)
        case 2: return Color.indigo.opacity(0.65)
        default: return Color.indigo
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.indigo)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
