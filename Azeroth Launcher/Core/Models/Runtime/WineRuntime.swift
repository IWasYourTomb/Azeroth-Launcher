//
//  WineRuntime.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

struct WineRuntime: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var version: String
    var executableURL: URL
    var isDefault: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        version: String,
        executableURL: URL,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.executableURL = executableURL
        self.isDefault = isDefault
    }

    var displayName: String {
        "\(name) \(version)"
    }

    var isAvailable: Bool {
        let fileManager = FileManager.default
        
        guard fileManager.isExecutableFile(
            atPath: executableURL.path
        ) else {
            return false
        }

        guard let wineserverURL else {
            return false
        }

        return fileManager.isExecutableFile(
            atPath: wineserverURL.path
        )
    }

    var wineserverURL: URL? {
        let executableDirectory = executableURL
            .deletingLastPathComponent()

        let candidates = [
            executableDirectory.appendingPathComponent("wineserver"),

            executableDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("bin/wineserver")
        ]

        return candidates.first {
            FileManager.default.isExecutableFile(
                atPath: $0.path
            )
        }
    }

    var runtimeDirectory: URL {
        executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL
    }
}
