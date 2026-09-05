import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: GestaltStore
    @AppStorage("pbHash") private var pbHash = ""
    @AppStorage("phoneHash") private var phoneHash = ""
    @AppStorage("localAuthHash") private var localAuthHash = ""
    @AppStorage("inCallHash") private var inCallHash = ""
    @AppStorage("accentColor") private var accentColor = AppAccent.blue.rawValue
    @AppStorage("appIcon") private var appIcon = AppIconCatalog.standard.id
    @AppStorage("customColor") private var customColor: Double = 0
    @AppStorage("useCustomColor") private var useCustomColor = false
    @State private var detectingHash = false
    @State private var detectingPhoneHash = false
    @State private var detectingLocalAuthHash = false
    @State private var detectingInCallHash = false
    @State private var showHashError = false
    @State private var hashErrorMessage = ""
    @State private var showBackupImporter = false
    @State private var pendingImportData: Data?
    @State private var showReplaceBackupConfirm = false
    @State private var showBackupError = false
    @State private var backupErrorMessage = ""
    @State private var showBackupImportedToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                appearance
                connection
                phoneConnection
                localAuthConnection
                inCallConnection
                backup
            }
            .padding(Theme.pagePadding)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could not detect container hash", isPresented: $showHashError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(hashErrorMessage)
        }
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.propertyList], onCompletion: handleBackupImport)
        .confirmationDialog("Replace existing backup?", isPresented: $showReplaceBackupConfirm, titleVisibility: .visible) {
            Button("Replace", role: .destructive, action: commitPendingImport)
            Button("Cancel", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("This overwrites your pristine recovery point with the imported file. This can't be undone.")
        }
        .alert("Could not import backup", isPresented: $showBackupError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupErrorMessage)
        }
        .toast(isPresented: $showBackupImportedToast, message: "Backup imported")
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Appearance")
            VStack(alignment: .leading, spacing: 10) {
                Text("Accent color")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 12) {
                    ForEach(AppAccent.allCases) { accent in
                        Button {
                            useCustomColor = false
                            accentColor = accent.rawValue
                        } label: {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if !useCustomColor && accentColor == accent.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accent.name)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom color")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 14) {
                    ColorPicker("", selection: Binding(
                        get: {
                            Color(hue: customColor, saturation: 0.75, brightness: 0.9)
                        },
                        set: { newColor in
                            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            UIColor(newColor).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                            customColor = h
                            useCustomColor = true
                        }
                    ))
                    .labelsHidden()
                    Circle()
                        .fill(Color(hue: customColor, saturation: 0.75, brightness: 0.9))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if useCustomColor {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    if useCustomColor {
                        Button("Reset") {
                            useCustomColor = false
                            accentColor = AppAccent.blue.rawValue
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("App icon")
                    .font(.subheadline.weight(.semibold))
                NavigationLink { AppIconPickerView() } label: {
                    HStack(spacing: 12) {
                        AppIconThumbnail(option: selectedIcon)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedIcon.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("by \(selectedIcon.creator)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var selectedIcon: AppIconOption {
        AppIconCatalog.option(forStoredID: appIcon)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("PosterBoard container")
            VStack(alignment: .leading, spacing: 14) {
                TextField("Container UUID", text: $pbHash)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Detect on device", systemImage: "scope", action: detectPosterBoardHash)
                        .disabled(detectingHash)
                    Spacer()
                    if detectingHash { ProgressView() }
                    if !pbHash.isEmpty {
                        Button("Clear", role: .destructive) { pbHash = "" }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                if !BadQuery.isAvailable {
                    Text("Detection is unavailable on this iOS version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var phoneConnection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Phone app container")
            VStack(alignment: .leading, spacing: 14) {
                TextField("Container UUID", text: $phoneHash)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Detect on device", systemImage: "scope", action: detectPhoneHash)
                        .disabled(detectingPhoneHash)
                    Spacer()
                    if detectingPhoneHash { ProgressView() }
                    if !phoneHash.isEmpty {
                        Button("Clear", role: .destructive) { phoneHash = "" }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                if !BadQuery.isAvailable {
                    Text("Detection is unavailable on this iOS version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var localAuthConnection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("LocalAuthenticationUI container")
            VStack(alignment: .leading, spacing: 14) {
                TextField("Container UUID", text: $localAuthHash)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Detect on device", systemImage: "scope", action: detectLocalAuthHash)
                        .disabled(detectingLocalAuthHash)
                    Spacer()
                    if detectingLocalAuthHash { ProgressView() }
                    if !localAuthHash.isEmpty {
                        Button("Clear", role: .destructive) { localAuthHash = "" }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                if !BadQuery.isAvailable {
                    Text("Detection is unavailable on this iOS version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var inCallConnection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("InCallService container")
            VStack(alignment: .leading, spacing: 14) {
                TextField("Container UUID", text: $inCallHash)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Detect on device", systemImage: "scope", action: detectInCallHash)
                        .disabled(detectingInCallHash)
                    Spacer()
                    if detectingInCallHash { ProgressView() }
                    if !inCallHash.isEmpty {
                        Button("Clear", role: .destructive) { inCallHash = "" }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                if !BadQuery.isAvailable {
                    Text("Detection is unavailable on this iOS version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var backup: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Backup")
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: store.backup.hasBackup ? "checkmark.shield.fill" : "shield")
                    .foregroundStyle(store.backup.hasBackup ? Theme.affirmative : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.backup.hasBackup ? "Pristine backup available" : "Backup will be created on first apply")
                        .font(.subheadline.weight(.medium))
                    if let info = store.backup.info {
                        Text("\(info.createdAt.formatted(date: .abbreviated, time: .shortened))  |  \(ByteCountFormatter.string(fromByteCount: Int64(info.byteCount), countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("This is the recovery point for all console changes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 20) {
                if store.backup.hasBackup {
                    ShareLink(item: store.backup.fileURL) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                Button { showBackupImporter = true } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
    }

    private func detectPosterBoardHash() {
        guard !detectingHash else { return }
        detectingHash = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let hash = try BadQuery.findPosterBoardHash().trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    pbHash = hash
                    detectingHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    detectingHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    hashErrorMessage = error.localizedDescription
                    showHashError = true
                }
            }
        }
    }

    private func detectPhoneHash() {
        guard !detectingPhoneHash else { return }
        detectingPhoneHash = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let hash = try BadQuery.findMobilePhoneHash().trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    phoneHash = hash
                    detectingPhoneHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    detectingPhoneHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    hashErrorMessage = error.localizedDescription
                    showHashError = true
                }
            }
        }
    }

    private func detectLocalAuthHash() {
        guard !detectingLocalAuthHash else { return }
        detectingLocalAuthHash = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let hash = try BadQuery.findContainerHash().trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    localAuthHash = hash
                    detectingLocalAuthHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    detectingLocalAuthHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    hashErrorMessage = error.localizedDescription
                    showHashError = true
                }
            }
        }
    }

    private func detectInCallHash() {
        guard !detectingInCallHash else { return }
        detectingInCallHash = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let hash = try BadQuery.findContainerHash().trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    inCallHash = hash
                    detectingInCallHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    detectingInCallHash = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    hashErrorMessage = error.localizedDescription
                    showHashError = true
                }
            }
        }
    }

    private func handleBackupImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                if store.backup.hasBackup {
                    pendingImportData = data
                    showReplaceBackupConfirm = true
                } else {
                    try store.backup.importBackup(from: data)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showBackupImportedToast = true
                }
            } catch {
                backupErrorMessage = error.localizedDescription
                showBackupError = true
            }
        case .failure(let error):
            backupErrorMessage = error.localizedDescription
            showBackupError = true
        }
    }

    private func commitPendingImport() {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        do {
            try store.backup.importBackup(from: data)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showBackupImportedToast = true
        } catch {
            backupErrorMessage = error.localizedDescription
            showBackupError = true
        }
    }
}
