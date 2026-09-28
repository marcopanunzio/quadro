import DashboardCore
import SwiftUI

/// Toast "Annulla" per l'eliminazione differita (REQ-092, DEC-020).
struct UndoToast: View {
    let title: String

    @Environment(\.palette) private var palette
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Text("“\(title)” eliminato")
                .font(.system(size: 13))
                .foregroundStyle(palette.bg)
            Button {
                model.undoDeletion()
            } label: {
                HStack(spacing: 4) {
                    Text("Annulla")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.now)
                    Text("⌘Z")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.now.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Annulla eliminazione")
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
        .padding(.leading, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.tx)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .fixedSize()
    }
}
