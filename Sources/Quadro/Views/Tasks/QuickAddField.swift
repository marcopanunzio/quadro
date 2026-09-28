import DashboardCore
import SwiftUI

/// Inserimento rapido di un task in linguaggio naturale (TASK-014, REQ-021).
struct QuickAddField: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nuovo task")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.tx2)

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(palette.tx2)
                TextField("", text: $text, prompt: Text("Chiamare Luca domani alle 15").foregroundStyle(palette.tx2))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onSubmit(submit)
                Text("⌘N")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tx2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(palette.ui2, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 9).fill(palette.bg))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.ui2, lineWidth: 1))

            Text("Riconosce “oggi”, “domani”, “venerdì”, “alle 15”, “15/10”. Invio per aggiungere.")
                .font(.system(size: 11))
                .foregroundStyle(palette.tx2)
        }
        .onChange(of: model.quickAddFocusRequest) { _, _ in isFocused = true }
    }

    private func submit() {
        let value = text
        text = ""
        Task { await model.quickAdd(value) }
    }
}
