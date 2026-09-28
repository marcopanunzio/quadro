import DashboardCore
import Foundation
import Testing

@Suite struct ThemeTests {
    @Test func flexokiHasAllAccents() {
        let theme = Theme.flexoki

        // Verifica che tutti gli 8 accenti siano presenti in light
        #expect(theme.light.accents.count == 8)
        #expect(theme.light.accents[.red] != nil)
        #expect(theme.light.accents[.orange] != nil)
        #expect(theme.light.accents[.yellow] != nil)
        #expect(theme.light.accents[.green] != nil)
        #expect(theme.light.accents[.cyan] != nil)
        #expect(theme.light.accents[.blue] != nil)
        #expect(theme.light.accents[.purple] != nil)
        #expect(theme.light.accents[.magenta] != nil)

        // Verifica che tutti gli 8 accenti siano presenti in dark
        #expect(theme.dark.accents.count == 8)
        #expect(theme.dark.accents[.red] != nil)
        #expect(theme.dark.accents[.orange] != nil)
        #expect(theme.dark.accents[.yellow] != nil)
        #expect(theme.dark.accents[.green] != nil)
        #expect(theme.dark.accents[.cyan] != nil)
        #expect(theme.dark.accents[.blue] != nil)
        #expect(theme.dark.accents[.purple] != nil)
        #expect(theme.dark.accents[.magenta] != nil)
    }

    @Test func flexokiHasCorrectHexValues() {
        let theme = Theme.flexoki

        // Campioni light
        #expect(theme.light.bg == RGB(hex: "#FFFCF0"))
        #expect(theme.light.accents[.red] == RGB(hex: "#AF3029"))
        #expect(theme.light.accents[.blue] == RGB(hex: "#205EA6"))

        // Campioni dark
        #expect(theme.dark.bg == RGB(hex: "#100F0F"))
        #expect(theme.dark.accents[.red] == RGB(hex: "#D14D41"))
        #expect(theme.dark.accents[.blue] == RGB(hex: "#4385BE"))
    }

    @Test func flexokiHasSemanticRoles() {
        let theme = Theme.flexoki

        #expect(theme.roles.overdue == .red)
        #expect(theme.roles.now == .orange)
        #expect(theme.roles.done == .green)
        #expect(theme.roles.selection == .blue)
    }

    @Test func oklabWhiteNearlyOne() {
        let white = RGB(r: 1.0, g: 1.0, b: 1.0)
        let oklabWhite = OKLab(white)

        // Bianco dovrebbe essere vicino a (1, 0, 0)
        #expect(abs(oklabWhite.L - 1.0) < 1e-3)
        #expect(abs(oklabWhite.a - 0.0) < 1e-3)
        #expect(abs(oklabWhite.b - 0.0) < 1e-3)
    }

    @Test func oklabBlackNearlyZero() {
        let black = RGB(r: 0.0, g: 0.0, b: 0.0)
        let oklabBlack = OKLab(black)

        // Nero dovrebbe essere vicino a (0, 0, 0)
        #expect(abs(oklabBlack.L - 0.0) < 1e-3)
        #expect(abs(oklabBlack.a - 0.0) < 1e-3)
        #expect(abs(oklabBlack.b - 0.0) < 1e-3)
    }

    @Test func nearestAccentAppleRed() {
        let appleRed = RGB(hex: "#FF3B30")
        let theme = Theme.flexoki
        let nearest = nearestAccent(to: appleRed, in: theme)

        #expect(nearest == .red)
    }

    @Test func nearestAccentAppleBlue() {
        // Apple blue #007AFF
        let appleBlue = RGB(hex: "#007AFF")
        let theme = Theme.flexoki
        let nearest = nearestAccent(to: appleBlue, in: theme)

        #expect(nearest == .blue)
    }

    @Test func nearestAccentApplePurple() {
        let applePurple = RGB(hex: "#AF52DE")
        let theme = Theme.flexoki
        let nearest = nearestAccent(to: applePurple, in: theme)

        #expect(nearest == .purple)
    }

    @Test func nearestAccentFlexokiAccents() {
        let theme = Theme.flexoki

        // Ogni accento Flexoki light dovrebbe mapparsi a se stesso
        for (accentName, accentRGB) in theme.light.accents {
            let nearest = nearestAccent(to: accentRGB, in: theme)
            #expect(nearest == accentName)
        }
    }

    @Test func themeRegistryReturnsFlexoki() {
        let theme = ThemeRegistry.theme(id: "flexoki")
        #expect(theme.id == "flexoki")
        #expect(theme.name == "Flexoki")
    }

    @Test func themeRegistryUnknownIdReturnsFlexoki() {
        let theme = ThemeRegistry.theme(id: "unknown-theme-id")
        #expect(theme.id == "flexoki")
    }

    @Test func themeRegistryAllContainsFlexoki() {
        let allThemes = ThemeRegistry.all
        #expect(allThemes.contains { $0.id == "flexoki" })
    }

    @Test(arguments: [
        ("#FF9500", AccentName.orange),
        ("#FFCC00", .yellow),
        ("#34C759", .green),
        ("#FF2D55", .red),
    ])
    func nearestAccentOtherAppleColors(hex: String, expected: AccentName) {
        #expect(nearestAccent(to: RGB(hex: hex), in: .flexoki) == expected)
    }
}
