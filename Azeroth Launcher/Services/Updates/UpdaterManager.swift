//
//  UpdaterManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class UpdaterManager {

    @ObservationIgnored
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        print("[UpdaterManager] Initialized")
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    var isUpdateInProgress: Bool {
        updaterController.updater.sessionInProgress
    }

    func start() {
        updaterController.startUpdater()
        print("[UpdaterManager] Updater started")
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            print("[UpdaterManager] Update check is unavailable")
            return
        }

        print("[UpdaterManager] Checking for updates...")
        updaterController.checkForUpdates(nil)
    }
}
