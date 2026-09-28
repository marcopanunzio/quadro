import SwiftUI

private struct SnapshotModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Vero durante `--snapshot`: ImageRenderer non disegna il contenuto delle ScrollView.
    var isSnapshot: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}

/// ScrollView verticale, sostituita da un contenitore semplice durante gli snapshot.
struct SnapshotFriendlyScrollView<Content: View>: View {
    @Environment(\.isSnapshot) private var isSnapshot
    let showsIndicators: Bool
    @ViewBuilder let content: Content

    init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        if isSnapshot {
            VStack(spacing: 0) { content }
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            ScrollView(.vertical, showsIndicators: showsIndicators) { content }
        }
    }
}

/// Applica `transform` solo fuori dagli snapshot (es. `dropDestination`, che ImageRenderer non sa disegnare).
struct LiveOnly<Base: View, Output: View>: View {
    @Environment(\.isSnapshot) private var isSnapshot
    let base: Base
    let transform: (Base) -> Output

    var body: some View {
        if isSnapshot { base } else { transform(base) }
    }
}

extension View {
    func liveOnly<Output: View>(_ transform: @escaping (Self) -> Output) -> some View {
        LiveOnly(base: self, transform: transform)
    }
}
