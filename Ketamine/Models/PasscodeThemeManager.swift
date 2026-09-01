//
//  PasscodeThemeManager.swift
//  Ketamine
//
//  Swaps the Phone app's passcode/lock-screen PNGs via the bad_query sandbox
//  escape. Every localized variant of a given asset is pixel-identical on
//  device — they're just duplicated under locale-prefixed filenames — so
//  matching is done by stripping the locale prefix rather than by knowing
//  the real locale list.
//

import Foundation
import ZIPFoundation

final class PasscodeThemeManager {

    static let shared = PasscodeThemeManager()

    enum PasscodeThemeError: LocalizedError {
        case notZip
        case noPNGsInPackage
        /// Carries a sample of the filenames/keys seen on each side, since the
        /// locale-prefix matching heuristic is unverified against a real
        /// device — this makes a mismatch self-diagnosing instead of a dead end.
        case noMatchingAssets(liveNames: [String], packageKeys: [String])
        case noBackup
        case noImagesToExtract

        var errorDescription: String? {
            switch self {
            case .notZip: return "That file isn't a zip or .passthm package."
            case .noPNGsInPackage: return "No PNG images were found in that package."
            case .noMatchingAssets(let liveNames, let packageKeys):
                let live = liveNames.prefix(6).joined(separator: ", ")
                let keys = packageKeys.prefix(6).joined(separator: ", ")
                return "None of the images in that package matched anything in the current theme. Device files: \(live). Package keys after stripping locale: \(keys)."
            case .noBackup: return "No backup of the original theme exists yet."
            case .noImagesToExtract: return "No dialer images were found to extract."
            }
        }
    }

    private init() {}

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Pristine copy of the live PNGs, taken once and never overwritten —
    /// same one-time-snapshot philosophy as the MobileGestalt backup.
    private var backupDirectory: URL {
        documentsDirectory.appendingPathComponent("Ketamine/PasscodeBackup", isDirectory: true)
    }

    var hasBackup: Bool {
        (try? fileManager.contentsOfDirectory(atPath: backupDirectory.path))?.isEmpty == false
    }

    static func cachePath(appHash: String) -> String {
        BadQuery.applicationContainerPath(appHash: appHash) + "/Library/Caches/TelephonyUI-10"
    }

    /// Cache pour LocalAuthenticationUIService
static func localAuthCachePath(appHash: String) -> String {
    BadQuery.applicationContainerPath(appHash: appHash) + "/Library/Caches/TelephonyUI-10"
}


    // MARK: - Locale-aware matching

    /// Groups a filename by everything after its first hyphen. Locale
    /// variants of the same asset share this suffix (e.g. "en-lock-mask.png"
    /// and "de-lock-mask.png" both key to "lock-mask.png"); an asset with no
    /// hyphen has no locale family and keys to its own full name.
    static func matchKey(for filename: String) -> String {
        let lowercased = filename.lowercased()
        guard let dash = lowercased.firstIndex(of: "-") else { return lowercased }
        return String(lowercased[lowercased.index(after: dash)...])
    }

    // MARK: - Backup

    func ensureBackup(appHash: String) throws {
        guard !hasBackup else { return }
        let livePath = Self.cachePath(appHash: appHash)
        let handle = try BadQuery.consume(path: livePath, create: true)
        defer { handle.release() }

        let names = ((try? fileManager.contentsOfDirectory(atPath: livePath)) ?? [])
            .filter { $0.lowercased().hasSuffix(".png") }
        guard !names.isEmpty else { return }

        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        for name in names {
            let source = URL(fileURLWithPath: livePath).appendingPathComponent(name)
            let destination = backupDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    // MARK: - Apply

    /// Unzips `packageURL`, matches its PNGs against the live cache by
    /// locale-stripped name, and overwrites every match in place. Backs up
    /// the original files first (once, ever, via `ensureBackup`). Returns
    /// how many files were replaced.
    @discardableResult
    func applyTheme(from packageURL: URL, appHash: String) throws -> Int {
        let accessing = packageURL.startAccessingSecurityScopedResource()
        defer { if accessing { packageURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: packageURL)
        // ZIP magic: files must start with "PK" — .passthm packages are zips
        // under a different extension.
        guard data.count >= 4, data[0] == 0x50, data[1] == 0x4B else {
            throw PasscodeThemeError.notZip
        }

        let livePath = Self.cachePath(appHash: appHash)
        try ensureBackup(appHash: appHash)

        let workDir = documentsDirectory
            .appendingPathComponent("UnzipItems", conformingTo: .directory)
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDir) }

        let zipURL = workDir.appendingPathComponent("package.zip")
        try data.write(to: zipURL, options: [.atomic])
        let extractedDir = workDir.appendingPathComponent("extracted")
        try fileManager.unzipItem(at: zipURL, to: extractedDir)

        let packagePNGs = Self.findPNGs(in: extractedDir)
        guard !packagePNGs.isEmpty else { throw PasscodeThemeError.noPNGsInPackage }

        // Every locale variant is identical, so the first PNG found under a
        // given key is as good as any other.
        var packageByKey: [String: URL] = [:]
        for url in packagePNGs {
            let key = Self.matchKey(for: url.lastPathComponent)
            if packageByKey[key] == nil { packageByKey[key] = url }
        }

        let handle = try BadQuery.consume(path: livePath, create: true)
        defer { handle.release() }

        let liveNames = ((try? fileManager.contentsOfDirectory(atPath: livePath)) ?? [])
            .filter { $0.lowercased().hasSuffix(".png") }

        var replaced = 0
        for name in liveNames {
            guard let source = packageByKey[Self.matchKey(for: name)] else { continue }
            let destination = URL(fileURLWithPath: livePath).appendingPathComponent(name)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            replaced += 1
        }

        guard replaced > 0 else {
            throw PasscodeThemeError.noMatchingAssets(
                liveNames: liveNames.sorted(),
                packageKeys: packageByKey.keys.sorted()
            )
        }
        return replaced
    }

    /// Restores every PNG in the live cache to what `ensureBackup` saved.
    func restoreOriginal(appHash: String) throws {
        guard hasBackup else { throw PasscodeThemeError.noBackup }
        let livePath = Self.cachePath(appHash: appHash)
        let handle = try BadQuery.consume(path: livePath, create: true)
        defer { handle.release() }

        let names = try fileManager.contentsOfDirectory(atPath: backupDirectory.path)
        for name in names {
            let source = backupDirectory.appendingPathComponent(name)
            let destination = URL(fileURLWithPath: livePath).appendingPathComponent(name)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    // MARK: - Extract

    /// Zips whichever PNGs are available — the saved backup if one exists,
    /// otherwise the live cache directly — as a starting point for making a
    /// custom theme. Purely a read: never creates a backup as a side effect.
    func extractImages(appHash: String) throws -> URL {
        var handle: BadQueryHandle?
        defer { handle?.release() }

        let sourceDir: URL
        if hasBackup {
            sourceDir = backupDirectory
        } else {
            let livePath = Self.cachePath(appHash: appHash)
            handle = try BadQuery.consume(path: livePath, create: true)
            sourceDir = URL(fileURLWithPath: livePath)
        }

        let names = ((try? fileManager.contentsOfDirectory(atPath: sourceDir.path)) ?? [])
            .filter { $0.lowercased().hasSuffix(".png") }
        guard !names.isEmpty else { throw PasscodeThemeError.noImagesToExtract }

        let exportDir = documentsDirectory.appendingPathComponent("ExportedThemes", conformingTo: .directory)
        if fileManager.fileExists(atPath: exportDir.path) {
            try fileManager.removeItem(at: exportDir)
        }
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let zipURL = exportDir.appendingPathComponent("DialerTheme.zip")
        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw PasscodeThemeError.noImagesToExtract
        }
        for name in names {
            try archive.addEntry(with: name, relativeTo: sourceDir)
        }
        return zipURL
    }

    private static func findPNGs(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }
        var results: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "png" {
            results.append(url)
        }
        return results
    }
}
