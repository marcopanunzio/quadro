import Foundation

public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case standard
        case subscription
        case birthday
    }

    public var id: String
    public var title: String
    public var color: RGB
    /// Nome dell'account (iCloud, Exchange, Google...).
    public var sourceTitle: String
    public var kind: Kind
    /// `false` per iscrizioni, compleanni e calendari condivisi in sola lettura (REQ-015).
    public var isWritable: Bool

    public init(id: String, title: String, color: RGB, sourceTitle: String, kind: Kind, isWritable: Bool) {
        self.id = id
        self.title = title
        self.color = color
        self.sourceTitle = sourceTitle
        self.kind = kind
        self.isWritable = isWritable
    }
}

public struct TaskListInfo: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var color: RGB
    public var sourceTitle: String
    /// Lista predefinita di Promemoria, usata per l'inserimento rapido (REQ-021).
    public var isDefault: Bool

    public init(id: String, title: String, color: RGB, sourceTitle: String, isDefault: Bool) {
        self.id = id
        self.title = title
        self.color = color
        self.sourceTitle = sourceTitle
        self.isDefault = isDefault
    }
}
