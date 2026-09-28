import SwiftUI

/// Riga "etichetta + controllo" dei popover di dettaglio (TASK-015): etichetta a sinistra (78pt, 12 tx2),
/// controllo a destra. Le righe vanno separate con `DetailDivider`.
struct DetailRow<Content: View>: View {
    @Environment(\.palette) private var palette

    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(palette.tx2)
                .frame(width: 78, alignment: .leading)
                .padding(.top, 3)
            content()
        }
        .padding(.vertical, 8)
    }
}

/// Linea sottile tra le righe di dettaglio.
struct DetailDivider: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Divider().overlay(palette.ui)
    }
}
