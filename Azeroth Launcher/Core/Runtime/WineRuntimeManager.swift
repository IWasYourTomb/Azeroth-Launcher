//
//  WineRuntimeManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class WineRuntimeManager {
    @ObservationIgnored
    private let detector: WineRuntimeDetector

    @ObservationIgnored
    private let validator: WineRuntimeValidator
    
    private(set) var runtimes: [WineRuntime] = []

    private(set) var isInstalling = false
    private(set) var installationError: String?

    @ObservationIgnored
    private let installer: WineRuntimeInstaller

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private let storageKey = "AzerothLauncher.WineRuntimes"

    var defaultRuntime: WineRuntime? {
        runtimes.first(where: { $0.isDefault })
    }

    init(
        installer: WineRuntimeInstaller = WineRuntimeInstaller(),
        detector: WineRuntimeDetector = WineRuntimeDetector(),
        validator: WineRuntimeValidator = WineRuntimeValidator()
    ) {
        self.installer = installer
        self.detector = detector
        self.validator = validator

        restore()
    }

    func installRuntime() async throws {
        guard !isInstalling else {
            throw RuntimeError.installationInProgress
        }

        isInstalling = true
        installationError = nil

        defer {
            isInstalling = false
        }
        do {
            let runtime = try await installer.install()
            try await register(runtime)
        } catch {
            installationError = error.localizedDescription
            throw error
        }
    }
    
    func register(_ runtime: WineRuntime) async throws {
        let runtimeDirectory = runtime.executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let validation = await validator.validate(
            at: runtimeDirectory
        )

        guard validation.isValid else {
            throw RuntimeError.invalidExecutable
        }

        if let index = runtimes.firstIndex(
            where: {
                $0.executableURL.standardizedFileURL ==
                runtime.executableURL.standardizedFileURL
            }
        ) {
            runtimes[index].name = runtime.name
            runtimes[index].version = validation.version ?? runtime.version

            save()
            return
        }

        var newRuntime = runtime

        newRuntime.version = validation.version ?? runtime.version
        newRuntime.isDefault = runtimes.isEmpty

        runtimes.append(newRuntime)

        save()
    }

    
    func detectRuntimes() async {
        let detectedRuntimes = await detector.detect()
        for runtime in detectedRuntimes {
            do {
                try await register(runtime)
            } catch {
                print(
                    "[WineRuntimeManager] Failed to register \(runtime.displayName): \(error.localizedDescription)"
                )
            }
        }
        print(
            "[WineRuntimeManager] Detection completed: \(detectedRuntimes.count)"
        )
    }
    
    func setDefault(id: UUID) {
        guard runtimes.contains(where: { $0.id == id }) else {
            return
        }

        for index in runtimes.indices {
            runtimes[index].isDefault = runtimes[index].id == id
        }

        save()
    }

    func remove(id: UUID) {
        let wasDefault = runtimes.first(
            where: { $0.id == id }
        )?.isDefault ?? false

        runtimes.removeAll {
            $0.id == id
        }

        if wasDefault, !runtimes.isEmpty {
            runtimes[0].isDefault = true
        }

        save()
    }


    private func save() {
        do {
            let data = try JSONEncoder().encode(runtimes)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("[WineRuntimeManager] Save failed: \(error)")
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: storageKey) else {
            return
        }

        do {
            let savedRuntimes = try JSONDecoder().decode(
                [WineRuntime].self,
                from: data
            )

            runtimes = savedRuntimes.filter {
                $0.isAvailable
            }

            normalizeDefaultRuntime()
            save()

            print(
                "[WineRuntimeManager] Restored \(runtimes.count) runtimes"
            )

        } catch {
            print(
                "[WineRuntimeManager] Restore failed: \(error)"
            )
        }
    }

    private func normalizeDefaultRuntime() {
        guard !runtimes.isEmpty else {
            return
        }

        let defaultIndices = runtimes.indices.filter {
            runtimes[$0].isDefault
        }

        guard let firstDefault = defaultIndices.first else {
            runtimes[0].isDefault = true
            return
        }

        for index in runtimes.indices {
            runtimes[index].isDefault = index == firstDefault
        }
    }
}


enum RuntimeError: LocalizedError {
    case invalidExecutable
    case runtimeNotFound
    case prefixNotFound
    case launchFailed
    case installationInProgress
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .invalidExecutable:
            return "The Wine executable is invalid."

        case .runtimeNotFound:
            return "Wine Runtime was not found."

        case .prefixNotFound:
            return "Wine Prefix was not found."

        case .launchFailed:
            return "Failed to launch the application."
            
        case .installationInProgress:
            return "Wine Runtime installation is already in progress."
        
        case .validationFailed:
            return "Wine Runtime validation failed."
        }
    }
}
