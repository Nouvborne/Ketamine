import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GestaltStore
    /// `nil` selects "All" — every tweak, uncategorized.
    @State private var category: TweakCategory? = .display
    @State private var configurationID: String?

    private var consoleCategories: [TweakCategory] {
        TweakCategory.allCases.filter { cat in
            cat != .ai && store.tweaks.contains { $0.category == cat }
        }
    }

    private var categoryTweaks: [Tweak] {
        guard let category else {
            return store.tweaks.filter { $0.category != .ai && $0.id != "product-type" }
        }
        return store.tweaks.filter { $0.category == category && $0.id != "product-type" }
    }

    private var selectedTweaks: [Tweak] {
        store.tweaks.filter(\.isEnabled)
    }

    var body: some View {
        NavigationStack {
            Group {
                if DeviceCompatibility.supportsFullFeatureSet {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            commandStatus
                            categoryRail
                            catalog
                            if !selectedTweaks.isEmpty { activeConfiguration }
                        }
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    FeatureUnsupportedView(feature: "Tweaks")
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tweaks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if DeviceCompatibility.supportsFullFeatureSet {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { ApplyChangesView() } label: {
                            Image(systemName: "bolt.horizontal.circle")
                        }
                        .disabled(store.enabledCount == 0)
                    }
                }
            }
        }
    }

    private var commandStatus: some View {
        HStack(alignment: .center, spacing: 16) {
            AppMark(name: "ConsoleGlyph", size: 52, tint: store.enabledCount == 0 ? .secondary : Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.enabledCount == 0 ? "No changes staged" : "\(store.enabledCount) changes staged")
                    .font(.headline)
                Text(store.enabledCount == 0 ? "Tap a capability to turn it on." : "Tap any active capability again to turn it off.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                categoryPill(title: "All", isSelected: category == nil) { category = nil }
                ForEach(consoleCategories) { item in
                    categoryPill(title: item.rawValue, isSelected: category == item) { category = item }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Theme.pagePadding)
        .padding(.horizontal, Theme.pagePadding)
    }

    private func categoryPill(title: String, isSelected: Bool, select: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) {
                select()
                configurationID = nil
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.accent.opacity(0.14) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(category?.rawValue ?? "All").font(.title3.weight(.semibold))
                Spacer()
                Text("\(categoryTweaks.count) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Laid out row by row rather than as one LazyVGrid so the
            // configuration panel can sit directly under the row holding the
            // tile that opened it, instead of after the whole catalog.
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(tweakRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(row) { tweak in
                            Button { toggle(tweak) } label: {
                                TweakCatalogTile(tweak: tweak, isConfiguring: configurationID == tweak.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(tweak.isEnabled ? "Disables this capability" : "Enables this capability")
                        }
                        // Keeps a lone trailing tile at half width.
                        if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                    }
                    if let tweak = configuringTweak,
                       row.contains(where: { $0.id == tweak.id }),
                       let detail = tweak.detail {
                        InlineTweakConfiguration(tweak: tweak, detail: detail)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    /// `categoryTweaks` split into rows of two, matching the old grid.
    private var tweakRows: [[Tweak]] {
        let tweaks = categoryTweaks
        return stride(from: 0, to: tweaks.count, by: 2).map { start in
            Array(tweaks[start..<min(start + 2, tweaks.count)])
        }
    }

    private var configuringTweak: Tweak? {
        guard let configurationID,
              let tweak = store.tweaks.first(where: { $0.id == configurationID }),
              tweak.isEnabled else { return nil }
        return tweak
    }

    private var activeConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Staged configuration", detail: "\(selectedTweaks.count)")
            VStack(spacing: 0) {
                ForEach(Array(selectedTweaks.prefix(4).enumerated()), id: \.element.id) { index, tweak in
                    HStack(spacing: 12) {
                        Image(systemName: tweak.symbol)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24)
                        Text(tweak.title)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 13)
                    if index < min(selectedTweaks.count, 4) - 1 { Divider().padding(.leading, 36) }
                }
                if selectedTweaks.count > 4 {
                    Text("+ \(selectedTweaks.count - 4) more changes")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 18)
            .liquidGlass()
        }
    }

    private func toggle(_ tweak: Tweak) {
        let willEnable = !tweak.isEnabled
        withAnimation(.snappy) {
            store.setEnabled(willEnable, for: tweak.id)
            configurationID = willEnable && tweak.detail != nil ? tweak.id : nil
        }
    }
}

struct TweakCatalogTile: View {
    let tweak: Tweak
    let isConfiguring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: tweak.symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(tweak.isEnabled ? Theme.accent : .secondary)
                Spacer()
                Image(systemName: tweak.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(tweak.isEnabled ? Theme.accent : Color(uiColor: .tertiaryLabel))
            }
            Spacer(minLength: 8)
            Text(tweak.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(tweak.isEnabled ? (isConfiguring ? "Configuring" : "Enabled") : tweak.subtitle)
                .font(.caption)
                .foregroundStyle(tweak.isEnabled ? Theme.accent : .secondary)
                .lineLimit(2)
        }
        // maxHeight lets paired tiles match the tallest in their row, the way
        // the grid used to. Applied before the padding so the glass background
        // expands with it.
        .frame(maxWidth: .infinity, minHeight: 142, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .background(tweak.isEnabled ? Theme.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .liquidGlass(cornerRadius: 22)
    }
}

struct InlineTweakConfiguration: View {
    @EnvironmentObject private var store: GestaltStore
    let tweak: Tweak
    let detail: TweakDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Configure \(tweak.title)")
            switch detail {
            case .picker(let options):
                Picker("Option", selection: store.pickerBinding(for: tweak.id)) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Text(option).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 138)
                .liquidGlass()
            case .textField(let placeholder, let keyboard):
                TextField(placeholder, text: store.textBinding(for: tweak.id))
                    .keyboardType(keyboard == .numeric ? .numberPad : .default)
                    .textFieldStyle(.roundedBorder)
                    .padding(18)
                    .liquidGlass()
            }
            if let note = tweak.notes {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ApplyChangesView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Command").font(.largeTitle.weight(.semibold))
                Text("Review staged changes before writing to the MobileGestalt cache.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(store.tweaks.filter(\.isEnabled).enumerated()), id: \.element.id) { index, tweak in
                        Label(tweak.title, systemImage: tweak.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                        if index < store.enabledCount - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 18)
                .liquidGlass()
                ActionButton(title: "Apply \(store.enabledCount) changes", systemImage: "bolt.fill", isBusy: store.isBusy, action: apply)
                Button("Restore pristine backup", role: .destructive) { showRestore = true }
                    .frame(maxWidth: .infinity)
                    .glassAction()
                    .disabled(!store.backup.hasBackup)
            }
            .padding(Theme.pagePadding)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showRestore) { RestoreSheet() }
        .alert("Could not apply changes", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func apply() {
        Task {
            do {
                _ = try await store.apply()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                RespringHelper.shared.trigger()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
