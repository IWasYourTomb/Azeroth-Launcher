//
//  GameLaunchSettingsManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class GameLaunchSettingsManager {
    private let fileManager: FileManager
    private let storageURL: URL

    private(set) var settingsByEdition: [GameEdition: GameLaunchSettings] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        self.storageURL = applicationSupport
            .appendingPathComponent(
                "AzerothLauncher",
                isDirectory: true
            )
            .appendingPathComponent("launch-settings.json")

        load()

        print("[GameLaunchSettingsManager] Initialized")
    }

    func settings(for edition: GameEdition) -> GameLaunchSettings {
        settingsByEdition[edition] ?? .default
    }

    func update(_ settings: GameLaunchSettings,for edition: GameEdition) {
        settingsByEdition[edition] = settings

        save()

        print(
            "[GameLaunchSettingsManager] Settings updated: \(edition.title)"
        )
    }

    func reset(for edition: GameEdition) {
        settingsByEdition.removeValue(forKey: edition)

        save()

        print(
            "[GameLaunchSettingsManager] Settings reset: \(edition.title)"
        )
    }


    private func load() {
        guard fileManager.fileExists(
            atPath: storageURL.path
        ) else {
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)

            settingsByEdition = try JSONDecoder().decode(
                [GameEdition: GameLaunchSettings].self,
                from: data
            )

            print(
                "[GameLaunchSettingsManager] Settings loaded: \(settingsByEdition.count)"
            )

        } catch {
            print(
                "[GameLaunchSettingsManager] Failed to load settings: \(error)"
            )
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]

            let data = try encoder.encode(settingsByEdition)

            try data.write(
                to: storageURL,
                options: .atomic
            )

        } catch {
            print(
                "[GameLaunchSettingsManager] Failed to save settings: \(error)"
            )
        }
    }
}
