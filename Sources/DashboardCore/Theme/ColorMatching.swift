import Foundation

/// Colore nello spazio OKLab (Björn Ottosson).
/// Linearizzazione da sRGB, trasformazione nei colori lineari (lms),
/// poi cuberoot e trasformazione finale a L, a, b.
public struct OKLab: Hashable, Sendable {
    public var L: Double
    public var a: Double
    public var b: Double

    /// Inizializza OKLab da un colore sRGB.
    public init(_ rgb: RGB) {
        // Linearizzazione sRGB
        let lr = rgb.r <= 0.04045 ? rgb.r / 12.92 : pow((rgb.r + 0.055) / 1.055, 2.4)
        let lg = rgb.g <= 0.04045 ? rgb.g / 12.92 : pow((rgb.g + 0.055) / 1.055, 2.4)
        let lb = rgb.b <= 0.04045 ? rgb.b / 12.92 : pow((rgb.b + 0.055) / 1.055, 2.4)

        // Trasformazione a lms
        let l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
        let m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
        let s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

        // Cuberoot
        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        // Trasformazione a L, a, b
        self.L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        self.a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        self.b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    }

    /// Distanza euclidea in spazio OKLab.
    public func distance(to other: OKLab) -> Double {
        let dL = L - other.L
        let da = a - other.a
        let db = b - other.b
        return sqrt(dL * dL + da * da + db * db)
    }
}

extension OKLab {
    /// Croma (saturazione percepita).
    public var chroma: Double { sqrt(a * a + b * b) }
    /// Tinta in radianti.
    public var hue: Double { atan2(b, a) }
}

/// Accento del tema (variante light) più vicino al colore dato (DEC-018).
/// Si confronta la tinta e non la distanza OKLab piena: i colori dei calendari Apple sono molto più
/// chiari e saturi degli accenti Flexoki, e con la luminosità nel conto il rosso finirebbe sull'arancio.
/// Per colori quasi grigi la tinta non è significativa e si torna alla distanza OKLab.
public func nearestAccent(to color: RGB, in theme: Theme) -> AccentName {
    let target = OKLab(color)
    let candidates = theme.light.accents.map { (name: $0.key, lab: OKLab($0.value)) }
    let score: (OKLab) -> Double
    if target.chroma < 0.04 {
        score = { target.distance(to: $0) }
    } else {
        score = { lab in
            let d = abs(target.hue - lab.hue)
            return min(d, 2 * .pi - d)
        }
    }
    // Ordine stabile a parità di punteggio.
    return candidates
        .min { lhs, rhs in
            let l = score(lhs.lab), r = score(rhs.lab)
            return l == r ? lhs.name.rawValue < rhs.name.rawValue : l < r
        }!
        .name
}
