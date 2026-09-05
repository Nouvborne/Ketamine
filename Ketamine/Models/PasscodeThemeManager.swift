//
//  PasscodeThemeManager.swift
//  Ketamine
//
//  Swaps the Phone, LocalAuthenticationUI, and InCallService app's passcode/lock-screen PNGs 
//  via the bad_query sandbox escape.
//

import Foundation
import ZIPFoundation

final class PasscodeThemeManager {

    static let shared = PasscodeThemeManager()

    enum PasscodeThemeError: LocalizedError {
        case notZip
        case noPNGsInPackage
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

    /// Pristine copy of the live PNGs, taken once and never overwritten.
    private var backupDirectory: URL {
        documentsDirectory.appendingPathComponent("Ketamine/PasscodeBackup", isDirectory: true)
    }

    var hasBackup: Bool {
        (try? fileManager.contentsOfDirectory(atPath: backupDirectory.path))?.isEmpty == false
    }

    /// Generates the cache path for a specific app container UUID
    static func cachePath(appHash: String) -> String {
        BadQuery.applicationContainerPath(appHash: appHash) + "/Library/Caches/TelephonyUI-10"
    }

    // MARK: - Locale-aware matching

    static func matchKey(for filename: String) -> String {
        let lowercased = filename.lowercased()
        guard let dash = lowercased.firstIndex(of: "-") else { return lowercased }
        return String(lowercased[lowercased.index(after: dash)...])
    }

    // MARK: - Backup

    /// Single appHash overload for backwards compatibility
    func ensureBackup(appHash: String) throws {
        try ensureBackup(appHashes: [appHash])
    }

    /// Ensures a pristine backup exists for all provided container hashes.
    func ensureBackup(appHashes: [String]) throws {
        guard !hasBackup else { return }
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        for appHash in appHashes where !appHash.isEmpty {
            let livePath = Self.cachePath(appHash: appHash)
            guard let handle = try? BadQuery.consume(path: livePath, create: true) else { continue }
            defer { handle.release() }

            let names = ((try? fileManager.contentsOfDirectory(atPath: livePath)) ?? [])
                .filter { $0.lowercased().hasSuffix(".png") }
            
            for name in names {
                let source = URL(fileURLWithPath: livePath).appendingPathComponent(name)
                let destination = backupDirectory.appendingPathComponent(name)
                if !fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.copyItem(at: source, to: destination)
                }
            }
        }
    }

    // MARK: - Apply

    /// Single appHash overload for backwards compatibility
    @discardableResult
    func applyTheme(from packageURL: URL, appHash: String) throws -> Int {
        try applyTheme(from: packageURL, appHashes: [appHash])
    }

    /// Applies theme across all target container hashes (Phone, LocalAuthenticationUI, InCallService).
    @discardableResult
    func applyTheme(from packageURL: URL, appHashes: [String]) throws -> Int {
        let accessing = packageURL.startAccessingSecurityScopedResource()
        defer { if accessing { packageURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: packageURL)
        guard data.count >= 4, data[0] == 0x50, data[1] == 0x4B else {
            throw PasscodeThemeError.notZip
        }

        let validHashes = appHashes.filter { !$0.isEmpty }
        guard !validHashes.isEmpty else { return 0 }

        try ensureBackup(appHashes: validHashes)

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

        var packageByKey: [String: URL] = [:]
        for url in packagePNGs {
            let key = Self.matchKey(for: url.lastPathComponent)
            if packageByKey[key] == nil { packageByKey[key] = url }
        }

        var totalReplaced = 0
        var allLiveNamesSeen: [String] = []

        for appHash in validHashes {
            let livePath = Self.cachePath(appHash: appHash)
            guard let handle = try? BadQuery.consume(path: livePath, create: true) else { continue }

            let liveNames = ((try? fileManager.contentsOfDirectory(atPath: livePath)) ?? [])
                .filter { $0.lowercased().hasSuffix(".png") }
            allLiveNamesSeen.append(contentsOf: liveNames)

            for name in liveNames {
                guard let source = packageByKey[Self.matchKey(for: name)] else { continue }
                let destination = URL(fileURLWithPath: livePath).appendingPathComponent(name)
                if fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.removeItem(at: destination)
                }
                if (try? fileManager.copyItem(at: source, to: destination)) != nil {
                    totalReplaced += 1
                }
            }
            handle.release()
        }

        guard totalReplaced > 0 else {
            throw PasscodeThemeError.noMatchingAssets(
                liveNames: Array(Set(allLiveNamesSeen)).sorted(),
                packageKeys: packageByKey.keys.sorted()
            )
        }
        return totalReplaced
    }

    // MARK: - Restore

    /// Single appHash overload for backwards compatibility
    func restoreOriginal(appHash: String) throws {
        try restoreOriginal(appHashes: [appHash])
    }

    /// Restores original theme assets across all specified container hashes.
    func restoreOriginal(appHashes: [String]) throws {
        guard hasBackup else { throw PasscodeThemeError.noBackup }
        let validHashes = appHashes.filter { !$0.isEmpty }

        let names = (try? fileManager.contentsOfDirectory(atPath: backupDirectory.path)) ?? []

        for appHash in validHashes {
            let livePath = Self.cachePath(appHash: appHash)
            guard let handle = try? BadQuery.consume(path: livePath, create: true) else { continue }

            for name in names {
                let source = backupDirectory.appendingPathComponent(name)
                let destination = URL(fileURLWithPath: livePath).appendingPathComponent(name)
                if fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.removeItem(at: destination)
                }
                try? fileManager.copyItem(at: source, to: destination)
            }
            handle.release()
        }
    }

    // MARK: - Extract

    /// Single appHash overload for backwards compatibility
    func extractImages(appHash: String) throws -> URL {
        try extractImages(appHashes: [appHash])
    }

    func extractImages(appHashes: [String]) throws -> URL {
        var sourceDir: URL = backupDirectory

        if !hasBackup {
            if let firstHash = appHashes.first(where: { !$0.isEmpty }) {
                let livePath = Self.cachePath(appHash: firstHash)
                if let handle = try? BadQuery.consume(path: livePath, create: true) {
                    sourceDir = URL(fileURLWithPath: livePath)
                    handle.release()
                }
            }
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
