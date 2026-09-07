import SwiftUI


enum TweakCategory: String, CaseIterable, Identifiable {
    case display = "Display"
    case sound = "Sound"
    case haptics = "Haptics"
    case system = "System"
    case ai = "AI & Intelligence"
    
    var id: String { rawValue }
    
    var neonColor: Color {
        switch self {
        case .display: return Color(red: 0.02, green: 0.71, blue: 0.83) // Neon Cyan
        case .sound: return Color(red: 0.93, green: 0.28, blue: 0.60)   // Neon Pink
        case .haptics: return Color(red: 0.66, green: 0.33, blue: 0.97) // Neon Purple
        case .system: return Color(red: 0.06, green: 0.73, blue: 0.51)  // Neon Emerald
        case .ai: return Color(red: 0.96, green: 0.62, blue: 0.04)      // Neon Amber
        }
    }
}

struct Theme {
    static let accent = Color(red: 0.23, green: 0.51, blue: 0.96) // Electric Blue
    static let pagePadding: CGFloat = 16
}


struct FoggyGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var borderColor: Color = Color.white.opacity(0.12)
    var glowColor: Color = Color.clear
    var glowRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.65))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: glowColor, radius: glowRadius)
    }
}

extension View {
    func foggyGlass(
        cornerRadius: CGFloat = 22,
        borderColor: Color = Color.white.opacity(0.12),
        glowColor: Color = Color.clear,
        glowRadius: CGFloat = 0
    ) -> some View {
        self.modifier(FoggyGlassModifier(
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            glowColor: glowColor,
            glowRadius: glowRadius
        ))
    }
    
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        self.foggyGlass(cornerRadius: cornerRadius)
    }
    
    func glassAction() -> some View {
        self
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.red.opacity(0.15))
            .foregroundStyle(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
    }
}


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
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.08).ignoresSafeArea()
                
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .blur(radius: 80)
                    .frame(width: 260, height: 260)
                    .offset(x: -120, y: -250)
                
                Circle()
                    .fill(Color.pink.opacity(0.12))
                    .blur(radius: 90)
                    .frame(width: 280, height: 280)
                    .offset(x: 140, y: 100)
                
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .blur(radius: 80)
                    .frame(width: 250, height: 250)
                    .offset(x: -100, y: 300)

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
            }
            .navigationTitle("Tweaks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if DeviceCompatibility.supportsFullFeatureSet {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { ApplyChangesView() } label: {
                            Image(systemName: "bolt.horizontal.circle")
                                .font(.title3)
                                .foregroundStyle(Color.cyan)
                                .shadow(color: Color.cyan.opacity(0.6), radius: 6)
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
                    .foregroundStyle(.primary)
                Text(store.enabledCount == 0 ? "Tap a capability to turn it on." : "Tap any active capability again to turn it off.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .foggyGlass(cornerRadius: 20, borderColor: Color.white.opacity(0.08))
        .padding(.top, 8)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                categoryPill(title: "All", categoryItem: nil, isSelected: category == nil) { category = nil }
                ForEach(consoleCategories) { item in
                    categoryPill(title: item.rawValue, categoryItem: item, isSelected: category == item) { category = item }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Theme.pagePadding)
        .padding(.horizontal, Theme.pagePadding)
    }

    private func categoryPill(title: String, categoryItem: TweakCategory?, isSelected: Bool, select: @escaping () -> Void) -> some View {
        let accentColor = categoryItem?.neonColor ?? Color.cyan
        
        return Button {
            withAnimation(.snappy) {
                select()
                configurationID = nil
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? (categoryItem == nil ? Color.cyan : accentColor) : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? accentColor.opacity(0.18) : Color.slateGlass)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: isSelected ? accentColor.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }


    private var catalog: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(category?.rawValue ?? "All").font(.title3.weight(.semibold))
                Spacer()
                Text("\(categoryTweaks.count) available")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05), in: Capsule())
            }
            
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
            .foggyGlass(cornerRadius: 22, borderColor: Theme.accent.opacity(0.3), glowColor: Theme.accent.opacity(0.2), glowRadius: 10)
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

    private var categoryColor: Color {
        tweak.category.neonColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: tweak.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tweak.isEnabled ? Color.blue.opacity(0.9) : categoryColor)
                Spacer()
                Image(systemName: tweak.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tweak.isEnabled ? Theme.accent : categoryColor.opacity(0.7))
            }
            Spacer(minLength: 8)
            Text(tweak.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(tweak.isEnabled ? (isConfiguring ? "Configuring" : "Enabled") : tweak.subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(tweak.isEnabled ? Color.blue.opacity(0.8) : categoryColor.opacity(0.9))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 142, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .foggyGlass(
            cornerRadius: 22,
            borderColor: tweak.isEnabled ? Theme.accent.opacity(0.7) : categoryColor.opacity(0.35),
            glowColor: tweak.isEnabled ? Theme.accent.opacity(0.35) : categoryColor.opacity(0.18),
            glowRadius: tweak.isEnabled ? 12 : 8
        )
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
                .foggyGlass(cornerRadius: 18, borderColor: Color.cyan.opacity(0.35))
            case .textField(let placeholder, let keyboard):
                TextField(placeholder, text: store.textBinding(for: tweak.id))
                    .keyboardType(keyboard == .numeric ? .numberPad : .default)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .foggyGlass(cornerRadius: 16, borderColor: Color.purple.opacity(0.4))
            }
            if let note = tweak.notes {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.amberAccent)
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.amberAccent)
                }
                .padding(10)
                .background(Color.amberAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.amberAccent.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(14)
        .foggyGlass(cornerRadius: 22, borderColor: Color.cyan.opacity(0.3), glowColor: Color.cyan.opacity(0.15), glowRadius: 10)
    }
}


struct ApplyChangesView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showRestore = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.08).ignoresSafeArea()
            
            // Ambient Orbs
            Circle()
                .fill(Color.purple.opacity(0.2))
                .blur(radius: 90)
                .frame(width: 280, height: 280)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.cyan.opacity(0.2))
                .blur(radius: 90)
                .frame(width: 280, height: 280)
                .offset(x: 100, y: 200)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Command").font(.largeTitle.weight(.bold))
                    Text("Review staged changes before writing to the MobileGestalt cache.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(store.tweaks.filter(\.isEnabled).enumerated()), id: \.element.id) { index, tweak in
                            Label(tweak.title, systemImage: tweak.symbol)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.cyan)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                            if index < store.enabledCount - 1 { Divider() }
                        }
                    }
                    .padding(.horizontal, 18)
                    .foggyGlass(cornerRadius: 22, borderColor: Color.indigo.opacity(0.3), glowColor: Color.indigo.opacity(0.15), glowRadius: 10)

                    ActionButton(title: "Apply \(store.enabledCount) changes", systemImage: "bolt.fill", isBusy: store.isBusy, action: apply)

                    Button("Restore pristine backup", role: .destructive) { showRestore = true }
                        .frame(maxWidth: .infinity)
                        .glassAction()
                        .disabled(!store.backup.hasBackup)
                }
                .padding(Theme.pagePadding)
            }
        }
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
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                RespringHelper.shared.trigger()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}


extension Color {
    static let slateGlass = Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.6)
    static let amberAccent = Color(red: 0.96, green: 0.62, blue: 0.04)
}

enum KeyboardKind { case standard, numeric }

enum TweakDetail {
    case picker(options: [String])
    case textField(placeholder: String, keyboard: KeyboardKind)
}

struct Tweak: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let category: TweakCategory
    var isEnabled: Bool
    var detail: TweakDetail? = nil
    var notes: String? = nil
}

struct BackupStatus { var hasBackup: Bool = true }

class GestaltStore: ObservableObject {
    @Published var tweaks: [Tweak] = [
        Tweak(id: "always-on-display", title: "Always On Display", subtitle: "Enable low-power ambient refresh", symbol: "sun.max", category: .display, isEnabled: false, detail: .picker(options: ["1Hz Refresh", "Dynamic Dimming", "Show Wallpaper"]), notes: "May decrease battery duration on older OLED displays."),
        Tweak(id: "pro-motion-override", title: "Force ProMotion 120Hz", subtitle: "Lock refresh rate to maximum", symbol: "bolt.circle", category: .display, isEnabled: false, detail: .picker(options: ["Adaptive", "Locked 120Hz", "Locked 90Hz"])),
        Tweak(id: "stage-manager", title: "Stage Manager Desktop", subtitle: "External display windowing mode", symbol: "square.grid.2x2", category: .display, isEnabled: false),
        Tweak(id: "haptic-keyboard", title: "System Keyboard Haptics", subtitle: "Tactile response on keystrokes", symbol: "hand.tap", category: .haptics, isEnabled: false, detail: .textField(placeholder: "Intensity level (1-100)", keyboard: .numeric)),
        Tweak(id: "lossless-audio", title: "Spatial Audio Boost", subtitle: "Increase head-tracking gain", symbol: "waveform.path", category: .sound, isEnabled: false),
        Tweak(id: "charge-limit", title: "Battery 80% Limit", subtitle: "Hardware charging ceiling", symbol: "battery.100.bolt", category: .system, isEnabled: false, detail: .textField(placeholder: "Max charge percentage (e.g. 80)", keyboard: .numeric), notes: "Requires restart to take effect.")
    ]
    @Published var isBusy: Bool = false
    var backup = BackupStatus()
    
    private var pickerSelections: [String: Int] = [:]
    private var textSelections: [String: String] = [:]

    var enabledCount: Int { tweaks.filter(\.isEnabled).count }

    func setEnabled(_ enabled: Bool, for tweakID: String) {
        if let idx = tweaks.firstIndex(where: { $0.id == tweakID }) {
            tweaks[idx].isEnabled = enabled
        }
    }

    func pickerBinding(for id: String) -> Binding<Int> {
        Binding(
            get: { self.pickerSelections[id] ?? 0 },
            set: { self.pickerSelections[id] = $0 }
        )
    }

    func textBinding(for id: String) -> Binding<String> {
        Binding(
            get: { self.textSelections[id] ?? "" },
            set: { self.textSelections[id] = $0 }
        )
    }

    func apply() async throws -> Bool {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
}

struct AppMark: View {
    let name: String
    let size: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint == .secondary ? Color.cyan.opacity(0.15) : Theme.accent.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint == .secondary ? Color.cyan.opacity(0.4) : Theme.accent.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: tint == .secondary ? Color.cyan.opacity(0.3) : Theme.accent.opacity(0.4), radius: 8)
            Image(systemName: "cpu")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint == .secondary ? Color.cyan : Color.blue)
        }
        .frame(width: size, height: size)
    }
}

struct SectionHeader: View {
    let title: String
    var detail: String? = nil

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack {
            Text(title).font(.headline.weight(.semibold))
            if let detail {
                Spacer()
                Text(detail)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.2), in: Capsule())
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: systemImage)
                    Text(title)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color.blue, Color.indigo, Color.purple], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.indigo.opacity(0.4), radius: 12)
        }
        .disabled(isBusy)
    }
}

struct DeviceCompatibility { static let supportsFullFeatureSet = true }

struct FeatureUnsupportedView: View {
    let feature: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
            Text("Feature Unsupported").font(.title3.weight(.bold))
            Text("\(feature) is not supported on this device version.").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct RestoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Color.gray.opacity(0.5)).frame(width: 40, height: 5).padding(.top, 8)
            Text("Restore Backup?").font(.title2.weight(.bold))
            Text("This will overwrite all active MobileGestalt configurations with the pristine factory backup.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Restore Pristine Backup", role: .destructive) { dismiss() }
                .font(.headline).frame(maxWidth: .infinity).padding().background(Color.red, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            Button("Cancel") { dismiss() }.font(.headline).foregroundStyle(.secondary)
        }
        .padding(24)
        .presentationDetents([.height(280)])
    }
}

class RespringHelper {
    static let shared = RespringHelper()
    func trigger() { print("Respring triggered") }
}
