import DashboardCore
import Foundation
import Testing

@Suite struct QuickAddParserTests {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.locale = Locale(identifier: "it_IT")
        c.firstWeekday = 2
        return c
    }()

    // Lunedì 28 settembre 2026, 10:40.
    static let now: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 9
        comps.day = 28
        comps.hour = 10
        comps.minute = 40
        return calendar.date(from: comps)!
    }()

    static let context = DateContext(calendar: calendar, now: { now })

    enum ExpectedDue: Sendable {
        case none
        case day(Int, Int, Int)
        case dateTime(Int, Int, Int, Int, Int)

        func matches(_ due: TaskDue?) -> Bool {
            switch self {
            case .none:
                return due == nil
            case .day(let y, let m, let d):
                return due == .day(DayDate(year: y, month: m, day: d))
            case .dateTime(let y, let m, let d, let h, let min):
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = d
                comps.hour = h
                comps.minute = min
                comps.second = 0
                let expected = QuickAddParserTests.calendar.date(from: comps)!
                if case .dateTime(let actual) = due {
                    return actual == expected
                }
                return false
            }
        }
    }

    struct Case: Sendable, CustomStringConvertible {
        let input: String
        let title: String
        let due: ExpectedDue

        var description: String { input }
    }

    // Tabella principale: ogni riga rispecchia un esempio della specifica (REQ inserimento rapido).
    static let cases: [Case] = [
        Case(input: "Chiamare Luca domani alle 15", title: "Chiamare Luca", due: .dateTime(2026, 9, 29, 15, 0)),
        Case(input: "Pagare bolletta oggi 17:30", title: "Pagare bolletta", due: .dateTime(2026, 9, 28, 17, 30)),
        Case(input: "Comprare pane", title: "Comprare pane", due: .none),
        Case(input: "Dentista lunedì", title: "Dentista", due: .day(2026, 10, 5)),
        Case(input: "Report venerdì alle 9", title: "Report", due: .dateTime(2026, 10, 2, 9, 0)),
        Case(input: "Riunione 15/10 ore 10:30", title: "Riunione", due: .dateTime(2026, 10, 15, 10, 30)),
        Case(input: "Scadenza assicurazione il 3 novembre", title: "Scadenza assicurazione", due: .day(2026, 11, 3)),
        Case(input: "Bollo 3/9", title: "Bollo", due: .day(2027, 9, 3)),
        Case(input: "Pagare affitto il 5", title: "Pagare affitto", due: .day(2026, 10, 5)),
        Case(input: "Spesa dopodomani", title: "Spesa", due: .day(2026, 9, 30)),
        Case(input: "Chiamare alle 9", title: "Chiamare", due: .dateTime(2026, 9, 28, 9, 0)),
        Case(input: "Palestra tra 3 giorni", title: "Palestra", due: .day(2026, 10, 1)),
        Case(input: "Ordinare mobili settimana prossima", title: "Ordinare mobili", due: .day(2026, 10, 5)),
        Case(input: "Ordinare mobili la prossima settimana", title: "Ordinare mobili", due: .day(2026, 10, 5)),
        Case(input: "Cena stasera", title: "Cena", due: .dateTime(2026, 9, 28, 20, 0)),
        Case(input: "Corsa domattina", title: "Corsa", due: .dateTime(2026, 9, 29, 9, 0)),
        Case(input: "Comprare 2 litri di latte", title: "Comprare 2 litri di latte", due: .none),
        Case(input: "Leggere capitolo 15", title: "Leggere capitolo 15", due: .none),
        Case(input: "Aggiornare versione 1.2", title: "Aggiornare versione 1.2", due: .none),
        Case(input: "domani", title: "domani", due: .none),
    ]

    @Test(arguments: cases) func tableDriven(_ c: Case) {
        let result = QuickAddParser.parse(c.input, context: Self.context)
        #expect(result.title == c.title)
        #expect(c.due.matches(result.due))
    }

    @Test func insensibileAMaiuscoleEAccenti() {
        let a = QuickAddParser.parse("Dentista lunedi", context: Self.context)
        let b = QuickAddParser.parse("Dentista LUNEDÌ", context: Self.context)
        #expect(a.title == "Dentista")
        #expect(b.title == "Dentista")
        #expect(a.due == b.due)
        #expect(a.due == .day(DayDate(year: 2026, month: 10, day: 5)))

        let c = QuickAddParser.parse("Dentista Martedi", context: Self.context)
        #expect(c.title == "Dentista")
        // martedì è strettamente dopo oggi (lunedì): domani, non la settimana prossima.
        #expect(c.due == .day(DayDate(year: 2026, month: 9, day: 29)))
    }

    @Test func formatiOrario() {
        let colon = QuickAddParser.parse("Chiamare alle 15:30", context: Self.context)
        let dot = QuickAddParser.parse("Chiamare alle 15.30", context: Self.context)
        let ore = QuickAddParser.parse("Chiamare ore 9", context: Self.context)
        let bare = QuickAddParser.parse("Chiamare 15:30", context: Self.context)

        #expect(colon.due == dot.due)
        #expect(colon.due == bare.due)
        if case .dateTime(let d)? = colon.due {
            #expect(Self.calendar.component(.hour, from: d) == 15)
            #expect(Self.calendar.component(.minute, from: d) == 30)
        } else {
            Issue.record("atteso un orario")
        }
        if case .dateTime(let d)? = ore.due {
            #expect(Self.calendar.component(.hour, from: d) == 9)
            #expect(Self.calendar.component(.minute, from: d) == 0)
        } else {
            Issue.record("atteso un orario")
        }
    }

    @Test func formatoConPuntoValidoSoloDopoAlleOOre() {
        // "15.30" senza "alle"/"ore" non è un orario: resta testo del titolo.
        let r = QuickAddParser.parse("Numero 15.30", context: Self.context)
        #expect(r.due == nil)
        #expect(r.title == "Numero 15.30")
    }

    @Test func orarioFuoriRangeNonERiconosciuto() {
        let r = QuickAddParser.parse("Riunione alle 25:99", context: Self.context)
        #expect(r.due == nil)
    }

    @Test func meseAbbreviato() {
        let r = QuickAddParser.parse("Regalo il 3 gen", context: Self.context)
        // 3 gennaio è già passato quest'anno (siamo a settembre): anno prossimo.
        #expect(r.due == .day(DayDate(year: 2027, month: 1, day: 3)))
        #expect(r.title == "Regalo")
    }

    @Test func giornoDelMeseSuMeseSuccessivoAGennaio() {
        // "il 1" col mese corrente = dicembre deve saltare all'anno successivo.
        let dicembreContext = DateContext(calendar: Self.calendar, now: {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = 12
            comps.day = 20
            comps.hour = 9
            return Self.calendar.date(from: comps)!
        })
        let r = QuickAddParser.parse("Rinnovo il 5", context: dicembreContext)
        #expect(r.due == .day(DayDate(year: 2027, month: 1, day: 5)))
    }

    @Test func dataConAnnoEsplicito() {
        let r = QuickAddParser.parse("Volo 15/10/2027 ore 8", context: Self.context)
        #expect(r.title == "Volo")
        if case .dateTime(let d)? = r.due {
            let comps = Self.calendar.dateComponents([.year, .month, .day, .hour], from: d)
            #expect(comps.year == 2027)
            #expect(comps.month == 10)
            #expect(comps.day == 15)
            #expect(comps.hour == 8)
        } else {
            Issue.record("atteso un dateTime")
        }
    }
}
