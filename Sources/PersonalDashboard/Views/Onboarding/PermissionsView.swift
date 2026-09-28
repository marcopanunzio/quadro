import DashboardCore
import SwiftUI

struct PermissionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Dashboard")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(palette.tx)
                    Text("Per mostrare la tua giornata servono alcuni permessi. I dati restano sul Mac: l'app legge e scrive direttamente su Calendario e Promemoria.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.tx2)
                        .lineLimit(nil)
                }
                VStack(spacing: 16) {
                    permissionRow(
                        kind: .calendar,
                        title: "Calendario",
                        description: "Eventi di tutti i tuoi calendari"
                    )
                    permissionRow(
                        kind: .reminders,
                        title: "Promemoria",
                        description: "Task da pianificare e completare"
                    )
                    permissionRow(
                        kind: .location,
                        title: "Posizione",
                        description: "Solo per il meteo, con precisione ridotta"
                    )
                    permissionRow(
                        kind: .mailAutomation,
                        title: "Mail",
                        description: "Numero di messaggi non letti, facoltativo",
                        isOptional: true
                    )
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Dopo aver cambiato i permessi in Impostazioni di Sistema torna qui: la dashboard si aggiorna da sola.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tx2)
                }
            }
            .padding(28)
            .frame(maxWidth: 520)
            .background(palette.bg2)
            .border(palette.ui, width: 1)
            .cornerRadius(14)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
    }

    @ViewBuilder
    private func permissionRow(
        kind: PermissionKind,
        title: String,
        description: String,
        isOptional: Bool = false
    ) -> some View {
        let status = statusForKind(kind, isOptional: isOptional)
        HStack(spacing: 12) {
            statusIcon(for: status)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(palette.tx)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(palette.tx2)
            }
            Spacer()
            if status == .notDetermined || status == .denied {
                Button(buttonLabel(for: status)) {
                    Task {
                        if status == .notDetermined {
                            await model.requestAccess(kind)
                        } else {
                            model.openSystemSettings(for: kind)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusIcon(for status: PermissionStatus) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.done)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(palette.overdue)
        case .notDetermined:
            Image(systemName: "circle.dashed")
                .foregroundStyle(palette.tx2)
        }
    }

    private func statusForKind(_ kind: PermissionKind, isOptional: Bool = false) -> PermissionStatus {
        switch kind {
        case .calendar:
            return model.calendarAccess
        case .reminders:
            return model.remindersAccess
        case .location:
            return model.locationAccess
        case .mailAutomation:
            return .notDetermined
        }
    }

    private func buttonLabel(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Consenti"
        case .denied:
            return "Apri Impostazioni di Sistema"
        case .granted:
            return ""
        }
    }
}
