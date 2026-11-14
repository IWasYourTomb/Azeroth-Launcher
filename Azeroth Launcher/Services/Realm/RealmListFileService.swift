//
//  RealmListFileService.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

enum RealmListFileError: LocalizedError {
    case invalidAddress
    case unableToReadFile
    case unableToCreateBackup(String)
    case unableToWriteFile(String)
    case realmlistNotFound

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return String(localized: "The realm address is invalid.")

        case .unableToReadFile:
            return String(localized: "Unable to read realmlist.wtf.")

        case .unableToCreateBackup(let reason):
            return """
            \(String(localized: "Unable to create a backup of realmlist.wtf."))

            \(reason)
            """

        case .unableToWriteFile(let reason):
            return """
            \(String(localized: "Unable to update realmlist.wtf."))

            \(reason)
            """

        case .realmlistNotFound:
            return String(localized: "realmlist.wtf was not found in the game directory.")
        }
    }
}

struct RealmListFileService {

    private let fileManager = FileManager.default


    func readCurrentRealm(installationPath: URL) throws -> String? {

        guard let fileURL = findRealmlistFile(
            installationPath: installationPath
        ) else {
            return nil
        }

        let contents: String

        do {
            contents = try String(
                contentsOf: fileURL,
                encoding: .utf8
            )
        } catch {
            throw RealmListFileError.unableToReadFile
        }

        return parseRealmAddress(from: contents)
    }

    func applyRealm(address: String, installationPath: URL) throws {

        let normalizedAddress = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard isValidAddress(normalizedAddress) else {
            throw RealmListFileError.invalidAddress
        }

        guard let fileURL = findRealmlistFile(
            installationPath: installationPath
        ) else {
            throw RealmListFileError.realmlistNotFound
        }

        let originalContents: String

        do {
            originalContents = try String(
                contentsOf: fileURL,
                encoding: .utf8
            )
        } catch {
            throw RealmListFileError.unableToReadFile
        }

        try createBackup(for: fileURL)
        
        let updatedContents = updateRealmDirective(
            in: originalContents,
            address: normalizedAddress
        )

        do {
            try updatedContents.write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw RealmListFileError.unableToWriteFile(
                error.localizedDescription
            )
        }
    }

    private func findRealmlistFile(installationPath: URL) -> URL? {

        let rootFile = installationPath
            .appendingPathComponent("realmlist.wtf")

        if fileManager.fileExists(atPath: rootFile.path) {
            return rootFile
        }

        let dataDirectory = installationPath
            .appendingPathComponent("Data", isDirectory: true)

        guard fileManager.fileExists(
            atPath: dataDirectory.path
        ) else {
            return nil
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: dataDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for directory in contents {

            guard let values = try? directory.resourceValues(
                forKeys: [.isDirectoryKey]
            ), values.isDirectory == true else {
                continue
            }

            let candidate = directory
                .appendingPathComponent("realmlist.wtf")

            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private func parseRealmAddress(from contents: String) -> String? {

        let pattern = #"(?im)^\s*set\s+realmlist\s+["']?([^"'\s]+)"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            contents.startIndex..<contents.endIndex,
            in: contents
        )

        guard let match = regex.firstMatch(
            in: contents,
            range: range
        ),
        let addressRange = Range(
            match.range(at: 1),
            in: contents
        ) else {
            return nil
        }

        return String(contents[addressRange])
    }

    private func updateRealmDirective(in contents: String, address: String) -> String {

        let pattern = #"(?im)^\s*set\s+realmlist\s+.*$"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return contents
        }

        let range = NSRange(
            contents.startIndex..<contents.endIndex,
            in: contents
        )

        let replacement = "set realmlist \(address)"

        if regex.firstMatch(
            in: contents,
            range: range
        ) != nil {

            return regex.stringByReplacingMatches(
                in: contents,
                range: range,
                withTemplate: replacement
            )
        }

        var updated = contents

        if !updated.isEmpty && !updated.hasSuffix("\n") {
            updated += "\n"
        }

        updated += replacement + "\n"

        return updated
    }

    private func isValidAddress(_ address: String) -> Bool {

        guard !address.isEmpty,
              address.count <= 253 else {
            return false
        }

        let forbiddenCharacters = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\"'\\;/"))

        guard address.rangeOfCharacter(
            from: forbiddenCharacters
        ) == nil else {
            return false
        }

        let pattern = #"^[a-zA-Z0-9.-]+(?::\d{1,5})?$|^\[[0-9a-fA-F:]+\](?::\d{1,5})?$"#

        guard address.range(
            of: pattern,
            options: .regularExpression
        ) != nil else {
            return false
        }

        if let portSeparator = address.lastIndex(of: ":") {
            let portString = address[address.index(after: portSeparator)...]

            if !portString.isEmpty,
               portString.allSatisfy(\.isNumber),
               let port = Int(portString) {

                return (1...65535).contains(port)
            }
        }

        return true
    }

    private func createBackup(for fileURL: URL) throws {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"

        let timestamp = formatter.string(from: Date())
        let uniqueID = UUID().uuidString.prefix(8)

        let backupName = "realmlist.\(timestamp)-\(uniqueID).wtf.backup"

        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(backupName)

        do {
            try fileManager.copyItem(
                at: fileURL,
                to: backupURL
            )
        } catch {
            print("Realm backup error: \(error)")
            print("Source: \(fileURL.path)")
            print("Destination: \(backupURL.path)")

            throw RealmListFileError.unableToCreateBackup(
                error.localizedDescription
            )
        }
    }
}
