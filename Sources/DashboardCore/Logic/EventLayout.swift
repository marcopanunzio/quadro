import Foundation

/// Ingresso per il calcolo del layout: un elemento con inizio/fine in una colonna-giorno.
public struct LayoutInput: Sendable {
    public var id: String
    public var start: Date
    public var end: Date

    public init(id: String, start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}

/// Colonna assegnata a un elemento e numero totale di colonne del suo cluster.
public struct LayoutSlot: Equatable, Sendable {
    public var column: Int
    public var columnCount: Int

    public init(column: Int, columnCount: Int) {
        self.column = column
        self.columnCount = columnCount
    }
}

public enum EventLayout {
    /// Layout a colonne per elementi sovrapposti in una colonna-giorno (come Calendario).
    /// Gli elementi che si toccano (`end == start`) non si sovrappongono.
    public static func layout(_ items: [LayoutInput]) -> [String: LayoutSlot] {
        guard !items.isEmpty else { return [:] }

        // Ordina per inizio crescente, a parità per durata decrescente.
        let sorted = items.sorted { a, b in
            if a.start != b.start { return a.start < b.start }
            let durationA = a.end.timeIntervalSince(a.start)
            let durationB = b.end.timeIntervalSince(b.start)
            return durationA > durationB
        }

        var result: [String: LayoutSlot] = [:]
        // Fine dell'ultimo elemento assegnato a ciascuna colonna, nel cluster corrente.
        var columnEnds: [Date] = []
        var clusterIDs: [String] = []
        var clusterMaxEnd: Date = .distantPast

        func flushCluster() {
            guard !clusterIDs.isEmpty else { return }
            let count = columnEnds.count
            for id in clusterIDs {
                result[id]?.columnCount = count
            }
            clusterIDs.removeAll()
            columnEnds.removeAll()
        }

        for item in sorted {
            if !clusterIDs.isEmpty && item.start >= clusterMaxEnd {
                flushCluster()
            }

            // Prima colonna libera: quella il cui ultimo elemento finisce entro l'inizio di questo.
            var assignedColumn: Int?
            for (idx, end) in columnEnds.enumerated() where end <= item.start {
                assignedColumn = idx
                break
            }

            let column: Int
            if let assigned = assignedColumn {
                column = assigned
                columnEnds[assigned] = item.end
            } else {
                column = columnEnds.count
                columnEnds.append(item.end)
            }

            clusterIDs.append(item.id)
            clusterMaxEnd = max(clusterMaxEnd, item.end)
            result[item.id] = LayoutSlot(column: column, columnCount: 0)
        }
        flushCluster()

        return result
    }
}
