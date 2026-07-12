import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            JournalTheme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        streakHero
                        statsGrid
                        activityCard
                        typeCard
                        weekdayCard
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(width: 540, height: 680)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(JournalTheme.accentSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(JournalTheme.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Insights")
                    .font(.title3.weight(.bold))
                Text("Your writing rhythm at a glance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(JournalIconButtonStyle(size: 34))
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(JournalTheme.stroke).frame(height: 1)
        }
    }

    private var streakHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 68, height: 68)
                Image(systemName: "flame.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.streak == 0 ? "Begin a new streak" : "\(store.streak)-day streak")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(streakMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                Text("\(store.longestStreak)")
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(JournalTheme.accent)
                Text("BEST")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .journalCard(radius: 20, shadow: 0.075)
    }

    private var streakMessage: String {
        if store.streak == 0 { return "One entry today is all it takes." }
        if store.streak == 1 { return "A small practice has started." }
        return "You have made time to notice what matters."
    }

    private var statsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
        return LazyVGrid(columns: columns, spacing: 10) {
            statTile("book.closed.fill", "\(store.entryCount)", "Entries", JournalTheme.accent)
            statTile("calendar", "\(store.entriesThisMonth)", "This month", .blue)
            statTile("text.word.spacing", store.totalWords.formatted(), "Words", .teal)
        }
    }

    private func statTile(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.13))
                .clipShape(Circle())
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .journalCard(radius: 16, shadow: 0.035)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Writing activity", subtitle: "The last six months", icon: "calendar.badge.clock")
            heatmap
            HStack(spacing: 5) {
                Spacer()
                Text("Less")
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(level))
                            .frame(width: 10, height: 10)
                    }
                }
                Text("More")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .journalCard(radius: 18, shadow: 0.04)
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("What you write", subtitle: "Entries by type", icon: "square.grid.2x2")
            if store.countsByType.isEmpty {
                Text("Your entry types will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                let maximum = store.countsByType.map(\.count).max() ?? 1
                ForEach(store.countsByType, id: \.type) { row in
                    HStack(spacing: 9) {
                        Image(systemName: row.type.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(row.type.color)
                            .frame(width: 25, height: 25)
                            .background(row.type.color.opacity(0.13))
                            .clipShape(Circle())
                        Text(row.type.label)
                            .font(.callout.weight(.medium))
                            .frame(width: 74, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(JournalTheme.surfaceMuted)
                                Capsule()
                                    .fill(row.type.color.opacity(0.82))
                                    .frame(width: max(8, proxy.size.width * CGFloat(row.count) / CGFloat(maximum)))
                            }
                        }
                        .frame(height: 9)
                        Text("\(row.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .journalCard(radius: 18, shadow: 0.04)
    }

    private var weekdayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Weekly rhythm", subtitle: "When you tend to write", icon: "waveform.path.ecg")
            let counts = store.countsByWeekday
            let maximum = max(counts.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text("\(counts[index])")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Capsule()
                            .fill(index == calendar.component(.weekday, from: Date()) - 1
                                  ? JournalTheme.accent
                                  : JournalTheme.accent.opacity(0.38))
                            .frame(height: max(7, 58 * CGFloat(counts[index]) / CGFloat(maximum)))
                        Text(calendar.veryShortWeekdaySymbols[index])
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
        }
        .padding(16)
        .journalCard(radius: 18, shadow: 0.04)
    }

    private func sectionHeader(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(JournalTheme.accent)
                .frame(width: 27, height: 27)
                .background(JournalTheme.accentSoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.bold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// One flexible-width column per calendar week, so the grid always spans
    /// the full card instead of piling fixed-size squares on the left. The
    /// range starts on a week boundary, which makes each row a real weekday
    /// and leaves the current week ragged on the right like a calendar.
    private var heatmap: some View {
        let weeksToShow = 26
        let today = calendar.startOfDay(for: Date())
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstDay = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: thisWeek) ?? today
        let dayCount = (calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0) + 1
        let days = store.dailyCounts(days: dayCount)
        let weeks = stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<weeks.count, id: \.self) { week in
                    Text(monthLabel(weeks, week) ?? "")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<weeks.count, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { slot in
                            if slot < weeks[week].count {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatColor(min(weeks[week][slot].count, 3)))
                                    .aspectRatio(1, contentMode: .fit)
                                    .help("\(weeks[week][slot].day.formatted(date: .abbreviated, time: .omitted)): \(weeks[week][slot].count)")
                            } else {
                                Color.clear.aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Label a column when it starts a new month; boundaries are weeks apart,
    /// so the overflowing text never collides with its neighbour.
    private func monthLabel(_ weeks: [[(day: Date, count: Int)]], _ week: Int) -> String? {
        guard week > 0, let first = weeks[week].first, let previous = weeks[week - 1].first,
              calendar.component(.month, from: first.day)
                  != calendar.component(.month, from: previous.day)
        else { return nil }
        return first.day.formatted(.dateTime.month(.abbreviated))
    }

    private func heatColor(_ level: Int) -> Color {
        switch level {
        case 0: return JournalTheme.surfaceMuted
        case 1: return JournalTheme.accent.opacity(0.34)
        case 2: return JournalTheme.accent.opacity(0.64)
        default: return JournalTheme.accent
        }
    }
}
