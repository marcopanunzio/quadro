import DashboardCore
import SwiftUI

extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
    }
}

/// Colori del tema già risolti per l'aspetto corrente. Le view leggono solo da qui, mai hex (REQ-107).
struct Palette {
    let theme: Theme
    let isDark: Bool
    private let colors: ThemeColors

    init(theme: Theme, isDark: Bool) {
        self.theme = theme
        self.isDark = isDark
        self.colors = theme.colors(dark: isDark)
    }

    var bg: Color { Color(colors.bg) }
    var bg2: Color { Color(colors.bg2) }
    var ui: Color { Color(colors.ui) }
    var ui2: Color { Color(colors.ui2) }
    var ui3: Color { Color(colors.ui3) }
    var tx: Color { Color(colors.tx) }
    var tx2: Color { Color(colors.tx2) }
    var tx3: Color { Color(colors.tx3) }

    func accent(_ name: AccentName) -> Color { Color(colors.accent(name)) }

    var overdue: Color { accent(theme.roles.overdue) }
    var now: Color { accent(theme.roles.now) }
    var done: Color { accent(theme.roles.done) }
    var selection: Color { accent(theme.roles.selection) }

    /// Riempimento tenue per i blocchi evento.
    func fill(_ name: AccentName) -> Color { accent(name).opacity(isDark ? 0.22 : 0.14) }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(theme: .flexoki, isDark: false)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Inietta la `Palette` del tema scelto in base all'aspetto effettivo della finestra.
struct PaletteProvider: ViewModifier {
    let themeID: String
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.palette, Palette(theme: ThemeRegistry.theme(id: themeID), isDark: colorScheme == .dark))
    }
}
