import DashboardCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var searchQuery = ""
    @State private var searchResults: [Place] = []
    @State private var isSearching = false
    @State private var searchError = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        @Bindable var model = model
        ZStack {
            palette.bg.ignoresSafeArea()
            TabView {
                generaleTab
                    .tabItem {
                        Label("Generale", systemImage: "gearshape")
                    }
                calendariTab
                    .tabItem {
                        Label("Calendari", systemImage: "calendar")
                    }
                meteoTab
                    .tabItem {
                        Label("Meteo", systemImage: "cloud.sun")
                    }
                mailTab
                    .tabItem {
                        Label("Mail", systemImage: "envelope")
                    }
            }
            .padding(0)
        }
        .frame(width: 520)
        .foregroundStyle(palette.tx)
    }

    // MARK: - Tab: Generale

    private var generaleTab: some View {
        Form {
            Section {
                @Bindable var model = model
                Picker("Vista iniziale", selection: $model.settings.defaultView) {
                    Text("Giorno").tag(CalendarViewMode.day)
                    Text("Settimana").tag(CalendarViewMode.week)
                    Text("Mese").tag(CalendarViewMode.month)
                }
                Picker("Inizio settimana", selection: $model.settings.firstWeekday) {
                    Text("Lunedì").tag(2)
                    Text("Domenica").tag(1)
                    Text("Sabato").tag(7)
                }
                HStack {
                    Text("Durata dei task nel calendario")
                    Spacer()
                    Stepper(
                        value: $model.settings.taskBlockMinutes,
                        in: 15...120,
                        step: 15
                    ) {
                        Text("\(model.settings.taskBlockMinutes) min")
                            .monospacedDigit()
                    }
                }
                Picker("Aspetto", selection: $model.settings.appearance) {
                    Text("Sistema").tag(AppearancePreference.system)
                    Text("Chiaro").tag(AppearancePreference.light)
                    Text("Scuro").tag(AppearancePreference.dark)
                }
                Picker("Tema", selection: $model.settings.themeID) {
                    ForEach(ThemeRegistry.all, id: \.id) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab: Calendari

    private var calendariTab: some View {
        Form {
            if model.calendars.isEmpty {
                Section {
                    Text("Nessun calendario: controlla i permessi.")
                        .foregroundStyle(palette.tx2)
                }
            } else {
                let accountsBySource = Dictionary(grouping: model.calendars, by: \.sourceTitle)
                ForEach(accountsBySource.sorted(by: { $0.key < $1.key }), id: \.key) { source, calendars in
                    Section(header: Text(source)) {
                        @Bindable var model = model
                        ForEach(calendars, id: \.id) { cal in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { !model.settings.hiddenCalendarIDs.contains(cal.id) },
                                    set: { isVisible in
                                        if isVisible {
                                            model.settings.hiddenCalendarIDs.remove(cal.id)
                                        } else {
                                            model.settings.hiddenCalendarIDs.insert(cal.id)
                                        }
                                    }
                                ))
                                .labelsHidden()
                                Circle()
                                    .fill(Color(palette.accent(model.accent(forCalendar: cal.id))))
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cal.title)
                                        .lineLimit(1)
                                    if !cal.isWritable {
                                        HStack(spacing: 4) {
                                            Image(systemName: "lock.fill")
                                            Text("Sola lettura")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(palette.tx2)
                                    }
                                }
                                Spacer()
                                if !cal.isWritable {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(palette.tx2)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            Section(header: Text("Liste promemoria")) {
                if model.taskLists.isEmpty {
                    Text("Nessuna lista.")
                        .foregroundStyle(palette.tx2)
                } else {
                    @Bindable var model = model
                    ForEach(model.taskLists, id: \.id) { list in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { !model.settings.hiddenTaskListIDs.contains(list.id) },
                                set: { isVisible in
                                    if isVisible {
                                        model.settings.hiddenTaskListIDs.remove(list.id)
                                    } else {
                                        model.settings.hiddenTaskListIDs.insert(list.id)
                                    }
                                }
                            ))
                            .labelsHidden()
                            Circle()
                                .fill(Color(palette.accent(model.accent(forCalendar: list.id))))
                                .frame(width: 12, height: 12)
                            Text(list.title)
                                .lineLimit(1)
                            Spacer()
                            if list.isDefault {
                                Text("predefinita")
                                    .font(.caption)
                                    .foregroundStyle(palette.tx2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(palette.ui)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab: Meteo

    private var meteoTab: some View {
        Form {
            Section {
                @Bindable var model = model
                Picker("Unità", selection: $model.settings.temperatureUnit) {
                    Text("°C").tag(TemperatureUnit.celsius)
                    Text("°F").tag(TemperatureUnit.fahrenheit)
                }
                .onChange(of: model.settings.temperatureUnit) {
                    Task { await model.refreshWeather() }
                }
            }

            Section(header: Text("Città di riserva")) {
                @Bindable var model = model
                if let fallback = model.settings.weatherFallbackPlace {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fallback.name)
                            if let detail = fallback.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(palette.tx2)
                            }
                        }
                        Spacer()
                        Button(action: {
                            model.settings.weatherFallbackPlace = nil
                            Task { await model.refreshWeather() }
                        }) {
                            Text("Rimuovi")
                        }
                    }
                }
                SearchWeatherPlaceField(
                    query: $searchQuery,
                    results: $searchResults,
                    isSearching: $isSearching,
                    hasError: $searchError,
                    weatherProvider: model.deps.weather,
                    onSelect: { place in
                        model.settings.weatherFallbackPlace = place
                        searchQuery = ""
                        searchResults = []
                        Task { await model.refreshWeather() }
                    }
                )
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab: Mail

    private var mailTab: some View {
        Form {
            Section {
                @Bindable var model = model
                Picker("Aggiorna le non lette ogni", selection: $model.settings.mailRefreshInterval) {
                    Text("1 minuto").tag(60)
                    Text("3 minuti").tag(180)
                    Text("5 minuti").tag(300)
                    Text("10 minuti").tag(600)
                }
            }
            Section {
                Text("Personal Dashboard legge solo il numero di messaggi non letti da Mail, e solo quando Mail è aperta.")
                    .font(.caption)
                    .foregroundStyle(palette.tx2)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - SearchWeatherPlaceField

private struct SearchWeatherPlaceField: View {
    @Binding var query: String
    @Binding var results: [Place]
    @Binding var isSearching: Bool
    @Binding var hasError: Bool
    let weatherProvider: any WeatherProvider
    let onSelect: (Place) -> Void
    @Environment(\.palette) private var palette
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            TextField("Cerca città...", text: $query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: query) { _, newValue in
                    updateSearch(newValue)
                }
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if hasError {
                Text("Ricerca non disponibile")
                    .font(.caption)
                    .foregroundStyle(palette.overdue)
            } else if !results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(results, id: \.self) { place in
                        Button(action: { onSelect(place) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .lineLimit(1)
                                    if let detail = place.detail {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundStyle(palette.tx2)
                                    }
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.tx)
                    }
                }
            }
        }
    }

    private func updateSearch(_ query: String) {
        searchTask?.cancel()
        hasError = false
        results = []

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            do {
                results = try await weatherProvider.searchPlaces(named: query)
                isSearching = false
            } catch {
                isSearching = false
                hasError = true
            }
        }
    }
}
