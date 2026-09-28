import DashboardCore
import SwiftUI

/// Riquadro calendario: barra strumenti in alto, poi la vista giorno/settimana (griglia oraria) o la vista mese.
struct CalendarPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            CalendarToolbar()
            Rectangle().fill(palette.ui).frame(height: 1)
            Group {
                if model.viewMode == .month {
                    MonthView()
                } else {
                    TimeGridView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
