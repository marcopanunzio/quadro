import DashboardCore
import Foundation
import SwiftUI

/// Mappatura pura tra posizione verticale nella griglia oraria e istanti di tempo.
/// Nessuno stato: usata sia per disegnare i blocchi sia per interpretare i gesti di trascinamento.
struct GridGeometry: Equatable {
    let hourHeight: CGFloat
    let calendar: Calendar

    init(hourHeight: CGFloat, calendar: Calendar) {
        self.hourHeight = hourHeight
        self.calendar = calendar
    }

    /// Altezza totale della griglia (24 ore).
    var totalHeight: CGFloat { hourHeight * 24 }

    /// Posizione verticale (dall'inizio del giorno) di un istante.
    func y(for date: Date, on day: DayDate) -> CGFloat {
        let dayStart = day.startDate(in: calendar)
        let seconds = date.timeIntervalSince(dayStart)
        return CGFloat(seconds / 3600) * hourHeight
    }

    /// Altezza corrispondente a una durata.
    func height(for duration: TimeInterval) -> CGFloat {
        CGFloat(duration / 3600) * hourHeight
    }

    /// Istante corrispondente a una posizione verticale nella colonna di `day`, agganciato a `snapMinutes`.
    func date(forY y: CGFloat, on day: DayDate, snapMinutes: Int) -> Date {
        let dayStart = day.startDate(in: calendar)
        let clampedY = min(max(y, 0), totalHeight)
        let totalSeconds = Double(clampedY / hourHeight) * 3600
        let raw = calendar.date(byAdding: .second, value: Int(totalSeconds.rounded()), to: dayStart) ?? dayStart
        return snap(raw, to: snapMinutes)
    }

    private func snap(_ date: Date, to minutes: Int) -> Date {
        guard minutes > 0 else { return date }
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute,
              let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else { return date }
        let snappedMinute = Int((Double(minute) / Double(minutes)).rounded()) * minutes
        return calendar.date(byAdding: .minute, value: snappedMinute, to: hourStart) ?? date
    }

    func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    func rangeLabel(_ start: Date, _ end: Date) -> String {
        "\(timeLabel(start))–\(timeLabel(end))"
    }
}
