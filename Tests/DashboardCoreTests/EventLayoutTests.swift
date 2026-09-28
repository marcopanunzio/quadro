import DashboardCore
import Foundation
import Testing

@Suite struct EventLayoutTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 9, day: 28, hour: hour, minute: minute).date!
    }

    @Test func emptyInput() {
        #expect(EventLayout.layout([]).isEmpty)
    }

    @Test func nonOverlappingEventsShareNoColumns() {
        let a = LayoutInput(id: "a", start: date(9), end: date(10))
        let b = LayoutInput(id: "b", start: date(11), end: date(12))
        let slots = EventLayout.layout([a, b])
        #expect(slots["a"] == LayoutSlot(column: 0, columnCount: 1))
        #expect(slots["b"] == LayoutSlot(column: 0, columnCount: 1))
    }

    @Test func touchingEventsDoNotOverlap() {
        let a = LayoutInput(id: "a", start: date(9), end: date(10))
        let b = LayoutInput(id: "b", start: date(10), end: date(11))
        let slots = EventLayout.layout([a, b])
        #expect(slots["a"] == LayoutSlot(column: 0, columnCount: 1))
        #expect(slots["b"] == LayoutSlot(column: 0, columnCount: 1))
    }

    @Test func twoOverlappingEventsGetTwoColumns() {
        let a = LayoutInput(id: "a", start: date(9), end: date(11))
        let b = LayoutInput(id: "b", start: date(10), end: date(12))
        let slots = EventLayout.layout([a, b])
        #expect(slots["a"]?.columnCount == 2)
        #expect(slots["b"]?.columnCount == 2)
        #expect(slots["a"]?.column != slots["b"]?.column)
    }

    @Test func thirdEventReusesFreedColumn() {
        // a: 9-10, b: 9-11 (si sovrappongono, 2 colonne). A parita' di inizio vince la durata
        // maggiore: b va nella colonna 0, a nella 1. c: 10-11 puo' riusare la colonna di a (finita alle 10).
        let a = LayoutInput(id: "a", start: date(9), end: date(10))
        let b = LayoutInput(id: "b", start: date(9), end: date(11))
        let c = LayoutInput(id: "c", start: date(10), end: date(11))
        let slots = EventLayout.layout([a, b, c])
        #expect(slots["b"]?.column == 0)
        #expect(slots["a"]?.column == 1)
        #expect(slots["c"]?.column == slots["a"]?.column)
        #expect(slots["a"]?.columnCount == 2)
        #expect(slots["b"]?.columnCount == 2)
        #expect(slots["c"]?.columnCount == 2)
    }

    @Test func transitiveClusterSharesColumnCount() {
        // a-b si sovrappongono, b-c si sovrappongono, a-c no: stesso cluster (transitivo), ma a e c
        // possono condividere la colonna perche' a finisce (10:30) prima che c inizi (11:00).
        let a = LayoutInput(id: "a", start: date(9), end: date(10, 30))
        let b = LayoutInput(id: "b", start: date(10), end: date(11, 30))
        let c = LayoutInput(id: "c", start: date(11), end: date(12))
        let slots = EventLayout.layout([a, b, c])
        #expect(slots["a"]?.columnCount == 2)
        #expect(slots["b"]?.columnCount == 2)
        #expect(slots["c"]?.columnCount == 2)
        #expect(slots["a"]?.column == slots["c"]?.column)
        #expect(slots["a"]?.column != slots["b"]?.column)
    }

    @Test func separateClustersDoNotShareColumnCount() {
        let a = LayoutInput(id: "a", start: date(9), end: date(10))
        let b = LayoutInput(id: "b", start: date(9), end: date(10))
        let c = LayoutInput(id: "c", start: date(11), end: date(12))
        let slots = EventLayout.layout([a, b, c])
        #expect(slots["a"]?.columnCount == 2)
        #expect(slots["b"]?.columnCount == 2)
        #expect(slots["c"]?.columnCount == 1)
    }

    @Test func longerEventPlacedFirstAtEqualStart() {
        let short = LayoutInput(id: "short", start: date(9), end: date(9, 30))
        let long = LayoutInput(id: "long", start: date(9), end: date(11))
        let overlap = LayoutInput(id: "overlap", start: date(9, 15), end: date(9, 45))
        let slots = EventLayout.layout([short, long, overlap])
        // "long" ha la stessa ora di inizio ma durata maggiore: va ordinato prima e prende colonna 0.
        #expect(slots["long"]?.column == 0)
    }
}
