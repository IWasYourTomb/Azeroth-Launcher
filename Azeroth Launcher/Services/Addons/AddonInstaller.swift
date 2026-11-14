//
//  AddonInstaller.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation
import ZIPFoundation

final class AddonInstaller {

    private let fileManager = FileManager.default
    private let directoryAccessManager = GameDirectoryAccessManager()

    enum InstallerError: LocalizedError {
        case missingBookmark
        case invalidArchive
        case unsafeArchivePath(String)
        case unsupportedArchiveEntry(String)
        case noAddonsFound
        case duplicateAddonNames
        case addonAlreadyExists(String)
        case invalidAddonName(String)

        var errorDescription: String? {
            switch self {
            case .missingBookmark:
                return "Game directory bookmark is missing."

            case .invalidArchive:
                return "Unable to open the ZIP archive."

            case .unsafeArchivePath(let path):
                return "Unsafe path detected in archive: \(path)"

            case .unsupportedArchiveEntry(let path):
                return "Unsupported archive entry: \(path)"

            case .noAddonsFound:
                return "No valid addons were found in the archive."

            case .duplicateAddonNames:
                return "The archive contains addons with duplicate names."

            case .addonAlreadyExists(let name):
                return "Addon already exists: \(name)"

            case .invalidAddonName(let name):
                return "Invalid addon folder name: \(name)"
            }
        }
    }

    func install(from archiveURL: URL,into installation: GameInstallation) throws -> [String] {

        guard let bookmarkData = installation.bookmarkData else {
            throw InstallerError.missingBookmark
        }

        let accessSession = try directoryAccessManager.openAccess(
            using: bookmarkData
        )

        defer {
            accessSession.close()
        }

        let addonsDirectory = installation.installationPath
            .appendingPathComponent("Interface")
            .appendingPathComponent("AddOns")

        try fileManager.createDirectory(
            at: addonsDirectory,
            withIntermediateDirectories: true
        )

        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let extractedDirectory = temporaryDirectory
            .appendingPathComponent("Extracted")

        try fileManager.createDirectory(
            at: extractedDirectory,
            withIntermediateDirectories: true
        )

        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        try extractArchive(
            archiveURL,
            to: extractedDirectory
        )

        let addonRoots = try findAddonRoots(
            in: extractedDirectory
        )

        guard !addonRoots.isEmpty else {
            throw InstallerError.noAddonsFound
        }

        let preparedAddons = try prepareAddonNames(
            addonRoots,
            extractedDirectory: extractedDirectory
        )

        let names = preparedAddons.map(\.name)

        guard Set(names.map { $0.lowercased() }).count == names.count else {
            throw InstallerError.duplicateAddonNames
        }


        for addon in preparedAddons {
            let destination = addonsDirectory
                .appendingPathComponent(addon.name)

            guard !fileManager.fileExists(atPath: destination.path) else {
                throw InstallerError.addonAlreadyExists(addon.name)
            }
        }

        var installedDirectories: [URL] = []

        do {
            for addon in preparedAddons {
                let destination = addonsDirectory
                    .appendingPathComponent(addon.name)

                try fileManager.copyItem(
                    at: addon.sourceURL,
                    to: destination
                )

                installedDirectories.append(destination)
            }
        } catch {
            for directory in installedDirectories.reversed() {
                try? fileManager.removeItem(at: directory)
            }

            throw error
        }

        return names
    }

    private func extractArchive(_ archiveURL: URL, to destination: URL) throws {

        guard let archive = Archive(
            url: archiveURL,
            accessMode: .read
        ) else {
            throw InstallerError.invalidArchive
        }

        let root = destination.standardizedFileURL

        for entry in archive {
            let normalizedPath = entry.path
                .replacingOccurrences(of: "\\", with: "/")

            let components = normalizedPath.split(separator: "/")

            guard !normalizedPath.hasPrefix("/"),
                  !components.isEmpty,
                  !components.contains(".."),
                  !components.contains(".")
            else {
                throw InstallerError.unsafeArchivePath(entry.path)
            }

            guard entry.type == .file || entry.type == .directory else {
                throw InstallerError.unsupportedArchiveEntry(entry.path)
            }

            let outputURL = destination
                .appendingPathComponent(normalizedPath)
                .standardizedFileURL

            let expectedPrefix = root.path + "/"

            guard outputURL.path.hasPrefix(expectedPrefix) else {
                throw InstallerError.unsafeArchivePath(entry.path)
            }

            if entry.type == .directory {
                try fileManager.createDirectory(
                    at: outputURL,
                    withIntermediateDirectories: true
                )
            } else {
                try fileManager.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                try archive.extract(
                    entry,
                    to: outputURL
                )
            }
        }
    }

    private func findAddonRoots(in directory: URL) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let tocFiles = contents.filter {
            $0.pathExtension.lowercased() == "toc"
        }

        if !tocFiles.isEmpty {
            return [directory]
        }

        var roots: [URL] = []

        for item in contents {
            let values = try item.resourceValues(
                forKeys: [.isDirectoryKey]
            )

            guard values.isDirectory == true else {
                continue
            }

            roots.append(
                contentsOf: try findAddonRoots(in: item)
            )
        }

        return roots
    }

    private struct PreparedAddon {
        let name: String
        let sourceURL: URL
    }

    private func prepareAddonNames(_ roots: [URL], extractedDirectory: URL) throws -> [PreparedAddon] {
        try roots.map { root in
            let name: String

            if root.standardizedFileURL == extractedDirectory.standardizedFileURL {
                let contents = try fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                guard let toc = contents.first(where: {
                    $0.pathExtension.lowercased() == "toc"
                }) else {
                    throw InstallerError.noAddonsFound
                }

                name = toc.deletingPathExtension().lastPathComponent
            } else {
                name = root.lastPathComponent
            }

            guard !name.isEmpty,
                  name != ".",
                  name != "..",
                  !name.contains("/"),
                  !name.contains("\\")
            else {
                throw InstallerError.invalidAddonName(name)
            }

            return PreparedAddon(
                name: name,
                sourceURL: root
            )
        }
    }
}
