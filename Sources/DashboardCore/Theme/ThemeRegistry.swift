import Foundation

/// Registry di temi disponibili.
public enum ThemeRegistry {
    /// Tutti i temi disponibili.
    public static let all: [Theme] = [
        .flexoki,
    ]

    /// Recupera un tema per ID. Se l'ID non è riconosciuto, ritorna flexoki.
    public static func theme(id: String) -> Theme {
        all.first { $0.id == id } ?? .flexoki
    }
}
