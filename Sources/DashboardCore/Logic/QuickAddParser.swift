import Foundation

/// Risultato dell'inserimento rapido di un task: titolo ripulito ed eventuale scadenza.
public struct QuickAddResult: Equatable, Sendable {
    public var title: String
    public var due: TaskDue?

    public init(title: String, due: TaskDue? = nil) {
        self.title = title
        self.due = due
    }
}

/// Parser per l'inserimento rapido dei promemoria in linguaggio naturale italiano
/// (es. "Chiamare Luca domani alle 15"). Non dipende da `NSDataDetector` (vedi report):
/// riconosce esplicitamente date relative, giorni della settimana, date esplicite e orari.
public enum QuickAddParser {

    public static func parse(_ text: String, context: DateContext) -> QuickAddResult {
        let calendar = context.calendar
        let today = context.today
        let folded = fold(text)

        var consumed: [Range<String.Index>] = []
        var dayDate: DayDate?
        var hour: Int?
        var minute: Int?

        if let day = findDayFragment(in: folded, today: today, calendar: calendar) {
            consumed.append(mapRange(day.range, from: folded, to: text))
            dayDate = day.day
            hour = day.hour
            minute = day.minute
        }

        if let time = findTimeFragment(in: folded) {
            consumed.append(mapRange(time.range, from: folded, to: text))
            hour = time.hour
            minute = time.minute
        }

        let due: TaskDue?
        if let h = hour {
            let day = dayDate ?? today
            var comps = DateComponents()
            comps.year = day.year
            comps.month = day.month
            comps.day = day.day
            comps.hour = h
            comps.minute = minute ?? 0
            comps.second = 0
            due = .dateTime(calendar.date(from: comps)!)
        } else if let day = dayDate {
            due = .day(day)
        } else {
            due = nil
        }

        let title = buildTitle(original: text, consumed: consumed)
        if title.isEmpty {
            return QuickAddResult(title: collapseWhitespace(text), due: nil)
        }
        return QuickAddResult(title: title, due: due)
    }

    // MARK: - Riconoscimento data

    private struct DayFragment {
        var range: Range<String.Index>
        var day: DayDate
        var hour: Int?
        var minute: Int?
    }

    private struct TimeFragment {
        var range: Range<String.Index>
        var hour: Int
        var minute: Int
    }

    /// Nome (o abbreviazione) del giorno della settimana -> numero `Calendar.weekday` (domenica = 1).
    private static let weekdays: [String: Int] = [
        "domenica": 1, "dom": 1,
        "lunedi": 2, "lun": 2,
        "martedi": 3, "mar": 3,
        "mercoledi": 4, "mer": 4,
        "giovedi": 5, "gio": 5,
        "venerdi": 6, "ven": 6,
        "sabato": 7, "sab": 7,
    ]

    /// Nome (o abbreviazione) del mese -> numero del mese.
    private static let months: [String: Int] = [
        "gennaio": 1, "gen": 1,
        "febbraio": 2, "feb": 2,
        "marzo": 3, "mar": 3,
        "aprile": 4, "apr": 4,
        "maggio": 5, "mag": 5,
        "giugno": 6, "giu": 6,
        "luglio": 7, "lug": 7,
        "agosto": 8, "ago": 8,
        "settembre": 9, "sett": 9, "set": 9,
        "ottobre": 10, "ott": 10,
        "novembre": 11, "nov": 11,
        "dicembre": 12, "dic": 12,
    ]

    /// Parole di collegamento da togliere ai bordi del titolo (o tra i frammenti rimossi).
    private static let connectorWords: Set<String> = ["il", "alle", "ore", "entro", "per", "di", "a", "la"]

    private static func alternation(_ dict: [String: Int]) -> String {
        dict.keys.sorted { $0.count > $1.count }.joined(separator: "|")
    }

    private static func findDayFragment(in folded: String, today: DayDate, calendar: Calendar) -> DayFragment? {
        // settimana prossima / la prossima settimana -> lunedì (primo giorno) della settimana successiva.
        if let r = firstMatch(#"\b(?:la\s+)?prossima\s+settimana\b|\bsettimana\s+prossima\b"#, in: folded) {
            let day = nextOccurrence(ofWeekday: calendar.firstWeekday, strictlyAfter: today, calendar: calendar)
            return DayFragment(range: r, day: day, hour: nil, minute: nil)
        }
        // tra N giorni
        if let m = firstRegexMatch(#"\btra\s+(\d{1,2})\s+giorn[oi]\b"#, in: folded), let n = Int(m.groups[0] ?? "") {
            return DayFragment(range: m.range, day: today.adding(days: n, calendar: calendar), hour: nil, minute: nil)
        }
        // dopodomani
        if let r = firstMatch(#"\bdopodomani\b"#, in: folded) {
            return DayFragment(range: r, day: today.adding(days: 2, calendar: calendar), hour: nil, minute: nil)
        }
        // domattina -> domani mattina (09:00)
        if let r = firstMatch(#"\bdomattina\b"#, in: folded) {
            return DayFragment(range: r, day: today.adding(days: 1, calendar: calendar), hour: 9, minute: 0)
        }
        // stasera -> oggi sera (20:00)
        if let r = firstMatch(#"\bstasera\b"#, in: folded) {
            return DayFragment(range: r, day: today, hour: 20, minute: 0)
        }
        // domani
        if let r = firstMatch(#"\bdomani\b"#, in: folded) {
            return DayFragment(range: r, day: today.adding(days: 1, calendar: calendar), hour: nil, minute: nil)
        }
        // oggi
        if let r = firstMatch(#"\boggi\b"#, in: folded) {
            return DayFragment(range: r, day: today, hour: nil, minute: nil)
        }
        // data esplicita gg/mm[/aaaa]
        if let m = firstRegexMatch(#"\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b"#, in: folded),
           let day = Int(m.groups[0] ?? ""), let month = Int(m.groups[1] ?? ""),
           day >= 1, day <= 31, month >= 1, month <= 12 {
            let year: Int
            if let yStr = m.groups[2], let y = Int(yStr) {
                year = y < 100 ? 2000 + y : y
            } else {
                year = resolveYear(month: month, day: day, today: today)
            }
            return DayFragment(range: m.range, day: DayDate(year: year, month: month, day: day), hour: nil, minute: nil)
        }
        // giorno + nome del mese (con eventuale "di" in mezzo)
        let monthAlt = alternation(months)
        if let m = firstRegexMatch(#"\b(\d{1,2})\s+(?:di\s+)?(\#(monthAlt))\b"#, in: folded),
           let day = Int(m.groups[0] ?? ""), day >= 1, day <= 31,
           let monthName = m.groups[1], let month = months[monthName] {
            let year = resolveYear(month: month, day: day, today: today)
            return DayFragment(range: m.range, day: DayDate(year: year, month: month, day: day), hour: nil, minute: nil)
        }
        // giorno del mese, solo numero ("il 5")
        if let m = firstRegexMatch(#"\bil\s+(\d{1,2})\b"#, in: folded), let day = Int(m.groups[0] ?? ""), day >= 1, day <= 31 {
            let (year, month) = resolveMonthForDay(day: day, today: today)
            return DayFragment(range: m.range, day: DayDate(year: year, month: month, day: day), hour: nil, minute: nil)
        }
        // giorno della settimana: prossima occorrenza strettamente dopo oggi
        let weekdayAlt = alternation(weekdays)
        if let m = firstRegexMatch(#"\b(\#(weekdayAlt))\b"#, in: folded), let token = m.groups[0], let target = weekdays[token] {
            let day = nextOccurrence(ofWeekday: target, strictlyAfter: today, calendar: calendar)
            return DayFragment(range: m.range, day: day, hour: nil, minute: nil)
        }
        return nil
    }

    private static func findTimeFragment(in folded: String) -> TimeFragment? {
        if let m = firstRegexMatch(#"\b(?:alle|ore)\s+(\d{1,2})(?:[:.](\d{2}))?\b"#, in: folded),
           let hour = Int(m.groups[0] ?? ""), hour >= 0, hour <= 23 {
            let minute = m.groups[1].flatMap(Int.init) ?? 0
            if minute >= 0, minute <= 59 {
                return TimeFragment(range: m.range, hour: hour, minute: minute)
            }
        }
        if let m = firstRegexMatch(#"\b(\d{1,2}):(\d{2})\b"#, in: folded),
           let hour = Int(m.groups[0] ?? ""), let minute = Int(m.groups[1] ?? ""),
           hour >= 0, hour <= 23, minute >= 0, minute <= 59 {
            return TimeFragment(range: m.range, hour: hour, minute: minute)
        }
        return nil
    }

    // MARK: - Calcoli su date

    /// Prossima occorrenza di `target` (numero `Calendar.weekday`) strettamente dopo `today`.
    private static func nextOccurrence(ofWeekday target: Int, strictlyAfter today: DayDate, calendar: Calendar) -> DayDate {
        let todayWeekday = calendar.component(.weekday, from: today.startDate(in: calendar))
        var diff = (target - todayWeekday + 7) % 7
        if diff == 0 { diff = 7 }
        return today.adding(days: diff, calendar: calendar)
    }

    /// Anno per una data gg/mm senza anno esplicito: quest'anno, o il prossimo se già passata.
    private static func resolveYear(month: Int, day: Int, today: DayDate) -> Int {
        let candidate = DayDate(year: today.year, month: month, day: day)
        return candidate < today ? today.year + 1 : today.year
    }

    /// Mese per un giorno del mese isolato ("il 5"): questo mese se il giorno non è ancora passato, altrimenti il prossimo.
    private static func resolveMonthForDay(day: Int, today: DayDate) -> (year: Int, month: Int) {
        if day >= today.day {
            return (today.year, today.month)
        } else if today.month == 12 {
            return (today.year + 1, 1)
        } else {
            return (today.year, today.month + 1)
        }
    }

    // MARK: - Ricerca con espressioni regolari

    private struct RegexMatch {
        var range: Range<String.Index>
        var groups: [String?]
    }

    private static func firstMatch(_ pattern: String, in s: String) -> Range<String.Index>? {
        guard let regex = try? Regex(pattern) else { return nil }
        return s.firstMatch(of: regex)?.range
    }

    private static func firstRegexMatch(_ pattern: String, in s: String) -> RegexMatch? {
        guard let regex = try? Regex(pattern), let match = s.firstMatch(of: regex) else { return nil }
        var groups: [String?] = []
        for i in 1..<match.output.count {
            if let r = match.output[i].range {
                groups.append(String(s[r]))
            } else {
                groups.append(nil)
            }
        }
        return RegexMatch(range: match.range, groups: groups)
    }

    // MARK: - Normalizzazione testo (fold accenti/maiuscole)

    /// Versione senza accenti e minuscola, carattere per carattere: stessa lunghezza dell'originale,
    /// così i range trovati nel testo "folded" si possono rimappare esattamente sull'originale.
    private static func fold(_ s: String) -> String {
        String(s.map { c -> Character in
            let f = String(c).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            return f.first ?? c
        })
    }

    private static func mapRange(_ range: Range<String.Index>, from folded: String, to original: String) -> Range<String.Index> {
        let lower = folded.distance(from: folded.startIndex, to: range.lowerBound)
        let upper = folded.distance(from: folded.startIndex, to: range.upperBound)
        let start = original.index(original.startIndex, offsetBy: lower)
        let end = original.index(original.startIndex, offsetBy: upper)
        return start..<end
    }

    // MARK: - Costruzione del titolo

    private static func buildTitle(original: String, consumed: [Range<String.Index>]) -> String {
        let tokens = tokenize(original)
        guard !tokens.isEmpty else { return "" }

        func isConsumed(_ r: Range<String.Index>) -> Bool {
            consumed.contains { overlaps($0, r) }
        }

        // Raggruppa i token consecutivi in "run" mantenuti/rimossi.
        var runs: [(removed: Bool, tokens: [Substring])] = []
        for t in tokens {
            let removed = isConsumed(t.range)
            if var last = runs.last, last.removed == removed {
                last.tokens.append(t.text)
                runs[runs.count - 1] = last
            } else {
                runs.append((removed, [t.text]))
            }
        }

        var kept: [Substring] = []
        for run in runs where !run.removed {
            var words = run.tokens
            while let first = words.first, connectorWords.contains(normalize(first)) {
                words.removeFirst()
            }
            while let last = words.last, connectorWords.contains(normalize(last)) {
                words.removeLast()
            }
            kept.append(contentsOf: words)
        }

        guard !kept.isEmpty else { return "" }
        return capitalizedFirst(kept.joined(separator: " "))
    }

    private static func normalize(_ s: Substring) -> String {
        fold(String(s)).lowercased()
    }

    private static func overlaps(_ a: Range<String.Index>, _ b: Range<String.Index>) -> Bool {
        a.lowerBound < b.upperBound && b.lowerBound < a.upperBound
    }

    private static func tokenize(_ s: String) -> [(range: Range<String.Index>, text: Substring)] {
        var result: [(Range<String.Index>, Substring)] = []
        var idx = s.startIndex
        while idx < s.endIndex {
            while idx < s.endIndex, s[idx].isWhitespace { idx = s.index(after: idx) }
            guard idx < s.endIndex else { break }
            let start = idx
            while idx < s.endIndex, !s[idx].isWhitespace { idx = s.index(after: idx) }
            result.append((start..<idx, s[start..<idx]))
        }
        return result
    }

    private static func capitalizedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    private static func collapseWhitespace(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        var lastWasSpace = false
        for c in trimmed {
            if c.isWhitespace {
                if !lastWasSpace { result.append(" ") }
                lastWasSpace = true
            } else {
                result.append(c)
                lastWasSpace = false
            }
        }
        return result
    }
}
