/// Colore sRGB con componenti in 0...1. Indipendente da AppKit/SwiftUI.
public struct RGB: Hashable, Codable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// `hex` nel formato `#RRGGBB` o `RRGGBB`.
    public init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(s, radix: 16) ?? 0
        self.init(
            r: Double((v >> 16) & 0xFF) / 255,
            g: Double((v >> 8) & 0xFF) / 255,
            b: Double(v & 0xFF) / 255
        )
    }
}
