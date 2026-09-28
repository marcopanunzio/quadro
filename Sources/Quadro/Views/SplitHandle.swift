import SwiftUI

/// Divisore trascinabile tra due riquadri. `onChanged` riceve lo spostamento dall'inizio del trascinamento,
/// misurato in coordinate globali (stabili anche se il divisore si muove mentre lo trascini).
struct SplitHandle: View {
    enum Orientation {
        /// Linea verticale, si trascina in orizzontale (larghezza dei riquadri).
        case vertical
        /// Linea orizzontale, si trascina in verticale (altezza).
        case horizontal
    }

    let orientation: Orientation
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    @Environment(\.palette) private var palette
    private let hitSize: CGFloat = 8

    var body: some View {
        let isVertical = orientation == .vertical
        Rectangle()
            .fill(palette.ui)
            .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
            .overlay {
                Color.clear
                    .frame(width: isVertical ? hitSize : nil, height: isVertical ? nil : hitSize)
                    .contentShape(Rectangle())
                    .pointerStyle(isVertical ? .columnResize : .rowResize)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                onChanged(isVertical ? value.translation.width : value.translation.height)
                            }
                            .onEnded { _ in onEnded() }
                    )
            }
            .zIndex(1)
    }
}
