import DashboardCore
import SwiftUI

struct HeaderBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 28) {
            DateSection()
            Divider().overlay(palette.ui).frame(height: 32)
            WeatherSection()
            Divider().overlay(palette.ui).frame(height: 32)
            BirthdaysSection()
            Divider().overlay(palette.ui).frame(height: 32)
            MailSection()
            Spacer()
            SummarySection()
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(palette.bg)
        .foregroundStyle(palette.tx)
    }
}

// MARK: - Date Section
private struct DateSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE d MMMM"
        let dateStr = formatter.string(from: model.now)
        let firstLetter = dateStr.first.map(String.init).map { $0.uppercased() } ?? ""
        let rest = String(dateStr.dropFirst())
        let weekNumber = Calendar(identifier: .iso8601).component(.weekOfYear, from: model.now)
        let year = model.calendar.component(.year, from: model.now)

        return VStack(alignment: .leading, spacing: 4) {
            Text(firstLetter + rest)
                .font(.system(size: 20, weight: .bold))

            Text("Settimana \(weekNumber) · \(year)")
                .font(.system(size: 12))
                .foregroundStyle(palette.tx2)
        }
        .frame(minWidth: 150)
    }
}

// MARK: - Weather Section
private struct WeatherSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch model.weather {
            case .idle:
                Text("Meteo…")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx2)

            case .loaded(let snapshot):
                weatherLoaded(snapshot)

            case .noLocation:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meteo non disponibile")
                        .font(.system(size: 13))
                    SettingsLink {
                        Text("Imposta città")
                            .font(.system(size: 11))
                    }
                }

            case .failed:
                Text("Meteo offline")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx2)
            }
        }
        .frame(minWidth: 120)
    }

    @ViewBuilder
    private func weatherLoaded(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Riga 1: temperatura + descrizione
            HStack(spacing: 4) {
                weatherIcon(snapshot.condition, isDaylight: snapshot.isDaylight)
                    .font(.system(size: 26))

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Int(snapshot.temperature.rounded()))°")
                        .font(.system(size: 15, weight: .semibold))
                    Text(conditionLabel(snapshot.condition))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tx2)
                }
            }

            // Riga 2: località e min/max
            if let first = snapshot.daily.first {
                let place = snapshot.placeName ?? "—"
                let minStr = Int(first.low.rounded())
                let maxStr = Int(first.high.rounded())
                Text("\(place) · max \(maxStr)° min \(minStr)°")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx2)
            }
        }
    }

    @ViewBuilder
    private func weatherIcon(_ condition: WeatherCondition, isDaylight: Bool) -> some View {
        switch condition {
        case .clear:
            Image(systemName: isDaylight ? "sun.max.fill" : "moon.stars.fill")
                .foregroundStyle(palette.accent(.yellow))

        case .partlyCloudy:
            Image(systemName: isDaylight ? "cloud.sun.fill" : "cloud.moon.fill")
                .foregroundStyle(palette.tx2)

        case .cloudy:
            Image(systemName: "cloud.fill")
                .foregroundStyle(palette.tx2)

        case .fog:
            Image(systemName: "cloud.fog.fill")
                .foregroundStyle(palette.tx2)

        case .drizzle:
            Image(systemName: "cloud.drizzle.fill")
                .foregroundStyle(palette.tx2)

        case .rain:
            Image(systemName: "cloud.rain.fill")
                .foregroundStyle(palette.tx2)

        case .snow:
            Image(systemName: "cloud.snow.fill")
                .foregroundStyle(palette.tx2)

        case .thunderstorm:
            Image(systemName: "cloud.bolt.rain.fill")
                .foregroundStyle(palette.tx2)
        }
    }

    private func conditionLabel(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: "Sereno"
        case .partlyCloudy: "Parz. nuvoloso"
        case .cloudy: "Nuvoloso"
        case .fog: "Nebbia"
        case .drizzle: "Pioggerella"
        case .rain: "Pioggia"
        case .snow: "Neve"
        case .thunderstorm: "Temporale"
        }
    }
}

// MARK: - Birthdays Section
private struct BirthdaysSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let birthdays = model.upcomingBirthdays
        let today = model.today

        VStack(alignment: .leading, spacing: 4) {
            if birthdays.isEmpty {
                Text("Nessun compleanno")
                    .font(.system(size: 13))

            } else {
                // Riga 1: compleanni di oggi
                let todaysBirthdays = birthdays.filter { event in
                    DayDate(event.start, calendar: model.calendar) == today
                }

                if todaysBirthdays.isEmpty {
                    Text("Nessun compleanno oggi")
                        .font(.system(size: 13))
                } else {
                    let names = todaysBirthdays.map { cleanBirthdayName($0.title) }.joined(separator: ", ")
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(palette.accent(model.accent(forCalendar: todaysBirthdays[0].calendarID)))
                        Text("Oggi: \(names)")
                            .font(.system(size: 13))
                    }
                }

                // Riga 2: prossimo compleanno
                if let next = birthdays.first(where: { event in
                    DayDate(event.start, calendar: model.calendar) > today
                }) {
                    let dayOfWeek = dayOfWeekShort(next.start, calendar: model.calendar)
                    let day = model.calendar.component(.day, from: next.start)
                    let name = cleanBirthdayName(next.title)
                    Text("\(dayOfWeek) \(day): \(name)")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tx2)
                }
            }
        }
        .frame(minWidth: 140)
    }

    private func cleanBirthdayName(_ title: String) -> String {
        var cleaned = title
        for prefix in ["Compleanno di ", "Compleanno: ", "Birthday of "] {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        if cleaned.hasSuffix("'s Birthday") {
            cleaned = String(cleaned.dropLast("'s Birthday".count))
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func dayOfWeekShort(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Mail Section
private struct MailSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch model.mail {
            case .unknown, .failed:
                Text("Mail —")
                    .font(.system(size: 13))

            case .closed:
                Text("Mail chiusa")
                    .font(.system(size: 13))

            case .notAuthorized:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mail: permesso negato")
                        .font(.system(size: 13))
                    Button(action: { model.openSystemSettings(for: .mailAutomation) }) {
                        Text("Consenti")
                            .font(.system(size: 11))
                    }
                }

            case .loaded(let summary):
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(palette.accent(.blue))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(summary.totalUnread) non lette")
                            .font(.system(size: 13, weight: .semibold))
                        let accountLabel = summary.accounts.count == 1 ? "1 account" : "\(summary.accounts.count) account"
                        Text(accountLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.tx2)
                    }
                }
                .help(mailTooltip(summary))
            }
        }
        .frame(minWidth: 140)
    }

    private func mailTooltip(_ summary: MailSummary) -> String {
        summary.accounts
            .map { "\($0.accountName): \($0.unreadCount)" }
            .joined(separator: "\n")
    }
}

// MARK: - Summary Section
private struct SummarySection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let summary = model.summary

        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.now)

            VStack(alignment: .leading, spacing: 2) {
                primaryLine(summary)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if summary.current != nil, let next = summary.next {
                    Text("Poi: \(next.title) alle \(time(next.start))")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tx2)
                        .lineLimit(1)
                }
            }

            Rectangle().fill(palette.ui).frame(width: 1, height: 28)

            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.eventCount == 1 ? "1 evento" : "\(summary.eventCount) eventi")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(summary.openTaskCount) task da fare")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.tx2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(palette.bg2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.ui, lineWidth: 1))
    }

    @ViewBuilder
    private func primaryLine(_ summary: DaySummary) -> some View {
        if let current = summary.current {
            Text("\(Text("In corso:").fontWeight(.semibold).foregroundStyle(palette.now)) \(current.title) · fino alle \(time(current.end))")
        } else if let next = summary.next {
            Text("\(Text("Prossimo:").fontWeight(.semibold).foregroundStyle(palette.now)) \(next.title) alle \(time(next.start))")
        } else {
            Text("Nessun altro evento oggi")
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: Locale(identifier: "it_IT"), calendar: model.calendar, timeZone: model.calendar.timeZone).hour(.defaultDigits(amPM: .omitted)).minute())
    }
}
