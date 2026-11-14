//
//  AppState.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    let gameManager: GameManager
    let rendererManager: RendererManager
    let runtimeManager: WineRuntimeManager
    let launchSettingsManager: GameLaunchSettingsManager
    let prefixManager: PrefixManager
    let gameLaunchManager: GameLaunchManager


    let gameInstallationService: GameInstallationService
    let directoryAccessManager: GameDirectoryAccessManager

    init() {
        let directoryManager = GameDirectoryAccessManager()
        self.directoryAccessManager = directoryManager
        self.gameManager = GameManager(
            directoryAccessManager: directoryManager
        )
        self.rendererManager = RendererManager()
        self.runtimeManager = WineRuntimeManager()
        let prefixManager = PrefixManager()
        self.prefixManager = prefixManager
        self.gameLaunchManager = GameLaunchManager(
            prefixManager: prefixManager
        )
        self.gameInstallationService = GameInstallationService()
        self.gameManager.restoreDirectoryAccess()
        self.launchSettingsManager = GameLaunchSettingsManager()
        Task {
            await runtimeManager.detectRuntimes()
        }
    }
}
