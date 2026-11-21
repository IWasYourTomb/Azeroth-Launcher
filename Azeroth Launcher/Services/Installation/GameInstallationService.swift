//
//  GameInstallationService.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct GameClientInspection {
    let edition: GameEdition
    let version: DetectedGameVersion
    let installationURL: URL
    let executableURL: URL
    let dataURL: URL
    let mpqCount: Int

    var executablePath: String {
        executableURL.path
    }

    var installationPath: String {
        installationURL.path
    }
}

final class GameInstallationService {
    private let validator = GameClientValidator()

    func inspect(
        at installationURL: URL
    ) throws -> GameClientInspection {
        let directoryURL = installationURL.standardizedFileURL

        let validation = try validator.validate(
            at: directoryURL
        )

        let executableURL = directoryURL
            .appendingPathComponent("Wow.exe")

        let dataURL = directoryURL
            .appendingPathComponent("Data", isDirectory: true)

        return GameClientInspection(
            edition: validation.edition,
            version: validation.version,
            installationURL: directoryURL,
            executableURL: executableURL,
            dataURL: dataURL,
            mpqCount: validation.mpqCount
        )
    }
}
