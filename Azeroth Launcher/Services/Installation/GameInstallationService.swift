//
//  GameInstallationService.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct GameClientInspection {
    let edition: GameEdition
    let installationURL: URL
    let executableURL: URL
    let dataURL: URL

    var executablePath: String {
        executableURL.path
    }

    var installationPath: String {
        installationURL.path
    }
}

final class GameInstallationService {
    private let fileManager = FileManager.default
    private let versionDetector = GameVersionDetector()

    func inspect(
        at installationURL: URL,
        edition: GameEdition
    ) throws -> GameClientInspection {
        let directoryURL = installationURL.standardizedFileURL

        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: directoryURL.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw InstallationError.directoryNotFound
        }

        let executableURL = directoryURL
            .appendingPathComponent("Wow.exe")
        
        let detectedVersion = try versionDetector.detect(
            at: executableURL
        )
        
        guard detectedVersion.edition == edition else {
            throw InstallationError.versionMismatch(
                expected: edition,
                actual: detectedVersion.edition
            )
        }

        guard fileManager.isReadableFile(
            atPath: executableURL.path
        ) else {
            throw InstallationError.executableNotFound
        }

        let dataURL = directoryURL
            .appendingPathComponent("Data", isDirectory: true)

        var isDataDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: dataURL.path,
            isDirectory: &isDataDirectory
        ), isDataDirectory.boolValue else {
            throw InstallationError.dataDirectoryNotFound
        }

        let dataContents = try fileManager.contentsOfDirectory(
            at: dataURL,
            includingPropertiesForKeys: nil
        )

        guard !dataContents.isEmpty else {
            throw InstallationError.dataDirectoryEmpty
        }

        return GameClientInspection(
            edition: edition,
            installationURL: directoryURL,
            executableURL: executableURL,
            dataURL: dataURL
        )
    }

    enum InstallationError: LocalizedError {
        case directoryNotFound
        case executableNotFound
        case dataDirectoryNotFound
        case dataDirectoryEmpty
        case versionMismatch(
            expected: GameEdition,
            actual: GameEdition
        )

        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "Папка игрового клиента не найдена."
            case .executableNotFound:
                return "В выбранной папке отсутствует Wow.exe."
            case .dataDirectoryNotFound:
                return "В папке клиента отсутствует директория Data."
            case .dataDirectoryEmpty:
                return "Директория Data пуста."
            case .versionMismatch(let expected, let actual):
                return """
                Выбрана версия \(expected.title),
                но обнаружен клиент \(actual.title).
                """
            }
        }
    }
}
