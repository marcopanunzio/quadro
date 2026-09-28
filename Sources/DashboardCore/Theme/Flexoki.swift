import Foundation

extension Theme {
    /// Tema Flexoki con palette light e dark.
    public static let flexoki: Theme = {
        let light = ThemeColors(
            bg: RGB(hex: "#FFFCF0"),
            bg2: RGB(hex: "#F2F0E5"),
            ui: RGB(hex: "#E6E4D9"),
            ui2: RGB(hex: "#DAD8CE"),
            ui3: RGB(hex: "#CECDC3"),
            tx: RGB(hex: "#100F0F"),
            tx2: RGB(hex: "#6F6E69"),
            tx3: RGB(hex: "#B7B5AC"),
            accents: [
                .red: RGB(hex: "#AF3029"),
                .orange: RGB(hex: "#BC5215"),
                .yellow: RGB(hex: "#AD8301"),
                .green: RGB(hex: "#66800B"),
                .cyan: RGB(hex: "#24837B"),
                .blue: RGB(hex: "#205EA6"),
                .purple: RGB(hex: "#5E409D"),
                .magenta: RGB(hex: "#A02F6F"),
            ]
        )

        let dark = ThemeColors(
            bg: RGB(hex: "#100F0F"),
            bg2: RGB(hex: "#1C1B1A"),
            ui: RGB(hex: "#282726"),
            ui2: RGB(hex: "#343331"),
            ui3: RGB(hex: "#403E3C"),
            tx: RGB(hex: "#CECDC3"),
            tx2: RGB(hex: "#878580"),
            tx3: RGB(hex: "#575653"),
            accents: [
                .red: RGB(hex: "#D14D41"),
                .orange: RGB(hex: "#DA702C"),
                .yellow: RGB(hex: "#D0A215"),
                .green: RGB(hex: "#879A39"),
                .cyan: RGB(hex: "#3AA99F"),
                .blue: RGB(hex: "#4385BE"),
                .purple: RGB(hex: "#8B7EC8"),
                .magenta: RGB(hex: "#CE5D97"),
            ]
        )

        let roles = SemanticRoles(
            overdue: .red,
            now: .orange,
            done: .green,
            selection: .blue
        )

        return Theme(id: "flexoki", name: "Flexoki", light: light, dark: dark, roles: roles)
    }()
}
