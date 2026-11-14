//
//  GameClientValidator.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct GameClientValidationResult {
    let edition: GameEdition
    let version: DetectedGameVersion
    let mpqCount: Int

    var summary: String {
        """
        Game: \(edition.title)
        Version: \(version.versionString)
        MPQ archives: \(mpqCount)
        """
    }
}

struct GameClientValidator {
    private let fileManager = FileManager.default
    private let versionDetector = GameVersionDetector()

    func validate(
        at installationURL: URL,
        expectedEdition: GameEdition
    ) throws -> GameClientValidationResult {
        let directory = installationURL.standardizedFileURL

        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: directory.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw ValidationError.directoryNotFound
        }

        let executableURL = directory
            .appendingPathComponent("Wow.exe")

        guard fileManager.isReadableFile(
            atPath: executableURL.path
        ) else {
            throw ValidationError.executableNotFound
        }

        let detectedVersion = try versionDetector.detect(
            at: executableURL
        )

        guard detectedVersion.edition == expectedEdition else {
            throw ValidationError.versionMismatch(
                expected: expectedEdition,
                actual: detectedVersion.edition
            )
        }

        let dataURL = directory
            .appendingPathComponent("Data", isDirectory: true)

        var isDataDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: dataURL.path,
            isDirectory: &isDataDirectory
        ), isDataDirectory.boolValue else {
            throw ValidationError.dataDirectoryNotFound
        }

        let mpqCount = try countMPQArchives(in: dataURL)

        guard mpqCount > 0 else {
            throw ValidationError.mpqArchivesNotFound
        }

        return GameClientValidationResult(
            edition: detectedVersion.edition,
            version: detectedVersion,
            mpqCount: mpqCount
        )
    }

    private func countMPQArchives(in directory: URL) throws -> Int {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .fileSizeKey
            ],
            options: [
                .skipsHiddenFiles,
                .skipsPackageDescendants
            ]
        ) else {
            throw ValidationError.cannotReadDataDirectory
        }

        var count = 0
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "mpq" else {
                continue
            }

            let values = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            )

            guard values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  fileSize > 0,
                  fileManager.isReadableFile(atPath: fileURL.path)
            else {
                continue
            }
            count += 1
        }
        return count
    }
    
    enum ValidationError: LocalizedError {
        case directoryNotFound
        case executableNotFound
        case versionMismatch(expected: GameEdition, actual: GameEdition)
        case dataDirectoryNotFound
        case cannotReadDataDirectory
        case mpqArchivesNotFound

        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "Папка игрового клиента не найдена."
            case .executableNotFound:
                return "Wow.exe отсутствует или недоступен для чтения."
            case .versionMismatch(let expected, let actual):
                return """
                Несовпадение версий!
                Ожидалась: \(expected.title)
                Обнаружена: \(actual.title)
                """
            case .dataDirectoryNotFound:
                return "Не найдена директория Data."
            case .cannotReadDataDirectory:
                return "Не удалось прочитать содержимое Data."
            case .mpqArchivesNotFound:
                return "В клиенте не найдены MPQ-архивы."
            }
        }
    }
}
