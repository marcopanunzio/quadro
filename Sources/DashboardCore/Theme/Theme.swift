/// Sistema dei temi (REQ-106, REQ-107). I valori concreti stanno nei singoli temi (es. `Theme.flexoki`).
public enum AccentName: String, Hashable, Sendable, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case magenta
}

public struct ThemeColors: Hashable, Sendable {
    public var bg: RGB
    public var bg2: RGB
    public var ui: RGB
    public var ui2: RGB
    public var ui3: RGB
    public var tx: RGB
    public var tx2: RGB
    public var tx3: RGB
    public var accents: [AccentName: RGB]

    public init(bg: RGB, bg2: RGB, ui: RGB, ui2: RGB, ui3: RGB, tx: RGB, tx2: RGB, tx3: RGB, accents: [AccentName: RGB]) {
        self.bg = bg
        self.bg2 = bg2
        self.ui = ui
        self.ui2 = ui2
        self.ui3 = ui3
        self.tx = tx
        self.tx2 = tx2
        self.tx3 = tx3
        self.accents = accents
    }

    public func accent(_ name: AccentName) -> RGB {
        accents[name] ?? tx
    }
}

/// Ruoli semantici: ogni tema dichiara quale accento usare.
public struct SemanticRoles: Hashable, Sendable {
    public var overdue: AccentName
    public var now: AccentName
    public var done: AccentName
    public var selection: AccentName

    public init(overdue: AccentName, now: AccentName, done: AccentName, selection: AccentName) {
        self.overdue = overdue
        self.now = now
        self.done = done
        self.selection = selection
    }
}

public struct Theme: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var light: ThemeColors
    public var dark: ThemeColors
    public var roles: SemanticRoles

    public init(id: String, name: String, light: ThemeColors, dark: ThemeColors, roles: SemanticRoles) {
        self.id = id
        self.name = name
        self.light = light
        self.dark = dark
        self.roles = roles
    }

    public func colors(dark isDark: Bool) -> ThemeColors {
        isDark ? dark : light
    }
}
