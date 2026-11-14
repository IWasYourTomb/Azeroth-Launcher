//
//  AddonManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

final class AddonManager {

    private let fileManager = FileManager.default

    func scan(installation: GameInstallation) throws -> [GameAddon] {

        let addonsDirectory = installation.installationPath
            .appendingPathComponent("Interface")
            .appendingPathComponent("AddOns")

        guard fileManager.fileExists(
            atPath: addonsDirectory.path
        ) else {
            return []
        }

        let directories = try fileManager.contentsOfDirectory(
            at: addonsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var addons: [GameAddon] = []

        for directory in directories {

            let resourceValues = try directory.resourceValues(
                forKeys: [.isDirectoryKey]
            )

            guard resourceValues.isDirectory == true else {
                continue
            }

            let actualFolderName = directory.lastPathComponent

            let isEnabled = !actualFolderName
                .lowercased()
                .hasSuffix(".disabled")

            let folderName = isEnabled
                ? actualFolderName
                : String(
                    actualFolderName.dropLast(".disabled".count)
                )

            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let tocFiles = contents
                .filter {
                    $0.pathExtension.lowercased() == "toc"
                }
                .sorted {
                    $0.lastPathComponent.localizedCaseInsensitiveCompare(
                        $1.lastPathComponent
                    ) == .orderedAscending
                }

            guard let tocFile = tocFiles.first else {
                continue
            }

            if let addon = try parseAddon(
                directory: directory,
                tocFile: tocFile,
                folderName: folderName,
                isEnabled: isEnabled
            ) {
                addons.append(addon)
            }
        }

        return addons.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func parseAddon(directory: URL, tocFile: URL, folderName: String, isEnabled: Bool) throws -> GameAddon? {

        let contents = try String(
            contentsOf: tocFile,
            encoding: .utf8
        )

        var metadata: [String: String] = [:]

        for line in contents.components(separatedBy: .newlines) {

            let trimmed = line.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard trimmed.hasPrefix("##"),
                  let separator = trimmed.firstIndex(of: ":")
            else {
                continue
            }

            let key = trimmed[
                trimmed.index(trimmed.startIndex, offsetBy: 2)..<separator
            ]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

            let value = trimmed[
                trimmed.index(after: separator)...
            ]
            .trimmingCharacters(in: .whitespacesAndNewlines)

            metadata[key] = value
        }

        let name = metadata["title"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? folderName

        let interfaces = metadata["interface"]?
            .split(separator: ",")
            .compactMap {
                Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
            } ?? []

        return GameAddon(
            id: directory.path,
            name: name,
            folderName: folderName,
            version: metadata["version"]?.nilIfEmpty,
            author: metadata["author"]?.nilIfEmpty,
            notes: metadata["notes"]?.nilIfEmpty,
            supportedInterfaces: interfaces,
            directoryURL: directory,
            tocURL: tocFile,
            isEnabled: isEnabled
        )
    }

    func setEnabled(_ addon: GameAddon, enabled: Bool) throws {

        guard addon.isEnabled != enabled else {
            return
        }

        let parentDirectory = addon.directoryURL
            .deletingLastPathComponent()

        let destinationName = enabled
            ? addon.folderName
            : addon.folderName + ".disabled"

        let destinationURL = parentDirectory
            .appendingPathComponent(
                destinationName,
                isDirectory: true
            )

        guard !fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw AddonManagerError.destinationAlreadyExists(
                destinationName
            )
        }

        try fileManager.moveItem(
            at: addon.directoryURL,
            to: destinationURL
        )
    }

    enum AddonManagerError: LocalizedError {

        case destinationAlreadyExists(String)

        var errorDescription: String? {

            switch self {

            case .destinationAlreadyExists(let name):
                return "An addon folder already exists: \(name)"
            }
        }
    }
}

private extension String {

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
