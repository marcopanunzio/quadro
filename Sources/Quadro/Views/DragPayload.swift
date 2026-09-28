import Foundation

/// Contenuto del drag & drop interno: una stringa con prefisso, così un testo trascinato da fuori non viene scambiato per un task.
enum DragPayload: Equatable {
    case task(id: String)
    case event(id: String)

    private static let taskPrefix = "quadro.task:"
    private static let eventPrefix = "quadro.event:"

    var string: String {
        switch self {
        case .task(let id): Self.taskPrefix + id
        case .event(let id): Self.eventPrefix + id
        }
    }

    init?(_ string: String) {
        if string.hasPrefix(Self.taskPrefix) {
            self = .task(id: String(string.dropFirst(Self.taskPrefix.count)))
        } else if string.hasPrefix(Self.eventPrefix) {
            self = .event(id: String(string.dropFirst(Self.eventPrefix.count)))
        } else {
            return nil
        }
    }
}
