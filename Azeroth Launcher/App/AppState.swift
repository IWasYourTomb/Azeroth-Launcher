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

            await gameLaunchManager.recoverSessions(
                installations: gameManager.installations,
                runtimes: runtimeManager.runtimes,
                defaultRuntime: runtimeManager.defaultRuntime
            )
        }
    }

    func forgetRuntime(id: UUID) throws {
        try validateRuntimeRemoval(id: id)

        runtimeManager.forget(id: id)

        print("[AppState] Runtime forgotten: \(id)")
    }

    func removeRuntimeFromDisk(id: UUID) async throws {
        try validateRuntimeRemoval(id: id)

        try await runtimeManager.removeFromDisk(id: id)

        print("[AppState] Runtime removed from disk: \(id)")
    }

    func reassignRuntime(from sourceRuntimeID: UUID, to destinationRuntimeID: UUID?) throws {

        guard runtimeManager.runtimes.contains(where: {
            $0.id == sourceRuntimeID
        }) else {
            throw RuntimeManagementError.runtimeNotFound
        }

        if let destinationRuntimeID {
            guard let destination = runtimeManager.runtimes.first(where: {
                $0.id == destinationRuntimeID
            }), destination.isAvailable else {
                throw RuntimeManagementError.destinationRuntimeUnavailable
            }
        }

        guard !gameLaunchManager.isRuntimeInUse(sourceRuntimeID) else {
            throw RuntimeManagementError.runtimeInUse
        }

        gameManager.reassignRuntime(
            from: sourceRuntimeID,
            to: destinationRuntimeID
        )
    }

    private func validateRuntimeRemoval(id: UUID) throws {
        guard let runtime = runtimeManager.runtimes.first(where: {
            $0.id == id
        }) else {
            throw RuntimeManagementError.runtimeNotFound
        }

        guard !gameLaunchManager.isRuntimeInUse(id) else {
            throw RuntimeManagementError.runtimeInUse
        }

        let assignedInstallations = gameManager.installations(
            usingRuntimeID: id
        )

        guard assignedInstallations.isEmpty else {
            let editions = assignedInstallations
                .map { $0.edition.title }
                .joined(separator: ", ")

            throw RuntimeManagementError.runtimeAssigned(editions)
        }
        
        guard !runtime.isDefault else {
            throw RuntimeManagementError.defaultRuntime
        }
    }
    
    func setRuntime(_ runtimeID: UUID?, for installationID: UUID) throws {
        guard let installation = gameManager.installations.first(where: {
            $0.id == installationID
        }) else {
            throw RuntimeManagementError.installationNotFound
        }

        guard !gameLaunchManager.isRunning(
            installationID: installationID
        ) else {
            throw RuntimeManagementError.runtimeInUse
        }

        if let runtimeID {
            guard let runtime = runtimeManager.runtimes.first(where: {
                $0.id == runtimeID
            }), runtime.isAvailable else {
                throw RuntimeManagementError.destinationRuntimeUnavailable
            }
        }

        gameManager.setRuntime(
            runtimeID,
            for: installation.id
        )
    }

    func effectiveRuntime(for installation: GameInstallation) -> WineRuntime? {
        if let runtimeID = installation.runtimeID {
            return runtimeManager.runtimes.first {
                $0.id == runtimeID && $0.isAvailable
            }
        }

        guard let defaultRuntime = runtimeManager.defaultRuntime,
              defaultRuntime.isAvailable else {
            return nil
        }

        return defaultRuntime
    }
}

enum RuntimeManagementError: LocalizedError {
    case runtimeNotFound
    case runtimeInUse
    case runtimeAssigned(String)
    case defaultRuntime
    case destinationRuntimeUnavailable
    case installationNotFound

    var errorDescription: String? {
        switch self {
        case .runtimeNotFound:
            return "Wine Runtime was not found."
        case .runtimeInUse:
            return """
            This Wine Runtime is currently used by a running game.
            Stop the game before removing the Runtime.
            """
        case .runtimeAssigned(let editions):
            return """
            This Wine Runtime is assigned to the following games: \(editions).

            Reassign these games before removing the Runtime.
            """
        case .defaultRuntime:
            return """
            This is the default Wine Runtime.

            Select another Runtime as default before removing it.
            """
        case .destinationRuntimeUnavailable:
            return "The destination Wine Runtime is unavailable."
        case .installationNotFound:
            return "Game installation was not found."
        }
    }
}
