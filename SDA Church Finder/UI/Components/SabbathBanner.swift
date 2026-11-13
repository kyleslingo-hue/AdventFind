import SwiftUI

struct SabbathBanner: View {
    let sabbath: SabbathTime
    var now: Date? = nil

    var body: some View {
        if let now {
            bannerContent(for: now)
        } else {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                bannerContent(for: timeline.date)
            }
        }
    }

    private func bannerContent(for currentDate: Date) -> some View {
        let active = sabbath.contains(currentDate)
        return VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label(active ? "Sabbath is here" : "The next sacred pause", systemImage: "sun.horizon")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(sabbath.timeZone.abbreviation(for: sabbath.start) ?? sabbath.timeZone.identifier)
                    .font(.caption.weight(.semibold))
            }
            HStack(alignment: .top, spacing: 24) {
                timeColumn("FRIDAY · BEGINS", date: sabbath.start)
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 50)
                timeColumn("SATURDAY · ENDS", date: sabbath.end)
            }
            Text(active ? "A little space for what matters." : sabbath.formattedStart)
                .font(.caption).foregroundStyle(AdventDesign.muted)
        }.foregroundStyle(AdventDesign.paper)
    }

    private func timeColumn(_ title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(AdventDesign.muted)
            Text(sabbath.formattedClock(date)).font(.system(.title, design: .rounded, weight: .light)).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
