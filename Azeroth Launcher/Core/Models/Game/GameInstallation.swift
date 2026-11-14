//
//  GameInstallation.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct GameInstallation: Identifiable, Codable {
    let id: UUID
    var edition: GameEdition
    var installationPath: URL
    var prefixPath: URL
    var bookmarkData: Data?
    var serverName: String?
    var isInstalled: Bool
    var runtimeID: UUID?

    init(
        id: UUID = UUID(),
        edition: GameEdition,
        installationPath: URL,
        prefixPath: URL,
        bookmarkData: Data? = nil,
        serverName: String? = nil,
        isInstalled: Bool = true,
        runtimeID: UUID? = nil
    ) {
        self.id = id
        self.edition = edition
        self.installationPath = installationPath
        self.prefixPath = prefixPath
        self.bookmarkData = bookmarkData
        self.serverName = serverName
        self.isInstalled = isInstalled
        self.runtimeID = runtimeID
    }
}
