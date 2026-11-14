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

    @ObservationIgnored
    private let installer: WineRuntimeInstaller

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private let storageKey = "AzerothLauncher.WineRuntimes"

    private(set) var runtimes: [WineRuntime] = []

    private(set) var isInstalling = false
    private(set) var isDetecting = false

    private(set) var installationError: String?
    private(set) var detectionError: String?

    var defaultRuntime: WineRuntime? {
        runtimes.first {
            $0.isDefault && $0.isAvailable
        } ?? runtimes.first {
            $0.isAvailable
        }
    }

    private var managedRuntimesDirectory: URL {
        FileManager.default
            .urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent(
                "AzerothLauncher/Runtimes",
                isDirectory: true
            )
            .standardizedFileURL
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

            print(
                "[WineRuntimeManager] Installed: \(runtime.displayName)"
            )

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
            runtimes[index].version =
                validation.version ?? runtime.version

            normalizeDefaultRuntime()
            save()

            return
        }

        var newRuntime = runtime

        newRuntime.version = validation.version ?? runtime.version
        newRuntime.isDefault = false

        runtimes.append(newRuntime)

        normalizeDefaultRuntime()
        save()

        print(
            "[WineRuntimeManager] Registered: \(newRuntime.displayName)"
        )
    }

    func detectRuntimes() async {
        guard !isDetecting else {
            return
        }

        isDetecting = true
        detectionError = nil

        defer {
            isDetecting = false
        }

        let detectedRuntimes = await detector.detect()

        var registeredCount = 0

        for runtime in detectedRuntimes {
            do {
                try await register(runtime)
                registeredCount += 1
            } catch {
                print(
                    """
                    [WineRuntimeManager] Failed to register \
                    \(runtime.displayName): \
                    \(error.localizedDescription)
                    """
                )
            }
        }

        normalizeDefaultRuntime()
        save()

        print(
            "[WineRuntimeManager] Detection completed. Found: \(registeredCount)"
        )
    }

    func setDefault(id: UUID) {
        guard let runtime = runtimes.first(
            where: { $0.id == id }
        ), runtime.isAvailable else {
            return
        }

        for index in runtimes.indices {
            runtimes[index].isDefault =
                runtimes[index].id == id
        }

        save()

        print(
            "[WineRuntimeManager] Default Runtime: \(runtime.displayName)"
        )
    }

    func refreshAvailability() {
        normalizeDefaultRuntime()
        save()
    }

    func forget(id: UUID) {
        guard runtimes.contains(where: { $0.id == id }) else {
            return
        }

        runtimes.removeAll {
            $0.id == id
        }

        normalizeDefaultRuntime()
        save()

        print("[WineRuntimeManager] Runtime forgotten: \(id)")
    }

    func remove(id: UUID) {
        forget(id: id)
    }

    func canRemoveFromDisk(_ runtime: WineRuntime) -> Bool {
        let runtimeDirectory = runtime.executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL

        return runtimeDirectory.deletingLastPathComponent()
            .standardizedFileURL == managedRuntimesDirectory
    }

    func removeFromDisk(id: UUID) async throws {
        guard let runtime = runtimes.first(
            where: { $0.id == id }
        ) else {
            return
        }

        guard canRemoveFromDisk(runtime) else {
            throw RuntimeError.cannotRemoveExternalRuntime
        }

        let runtimeDirectory = runtime.executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL

        let fileManager = FileManager.default

        if fileManager.fileExists(
            atPath: runtimeDirectory.path
        ) {
            do {
                try await Task.detached(priority: .utility) {
                    try FileManager.default.removeItem(
                        at: runtimeDirectory
                    )
                }.value

            } catch {
                throw RuntimeError.runtimeRemovalFailed(
                    error.localizedDescription
                )
            }
        }

        forget(id: id)

        print(
            "[WineRuntimeManager] Runtime deleted: \(runtimeDirectory.path)"
        )
    }


    private func save() {
        do {
            let data = try JSONEncoder().encode(runtimes)

            defaults.set(
                data,
                forKey: storageKey
            )

        } catch {
            print(
                "[WineRuntimeManager] Save failed: \(error)"
            )
        }
    }

    private func restore() {
        guard let data = defaults.data(
            forKey: storageKey
        ) else {
            return
        }

        do {
            runtimes = try JSONDecoder().decode(
                [WineRuntime].self,
                from: data
            )

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

        let availableIndices = runtimes.indices.filter {
            runtimes[$0].isAvailable
        }

        guard let firstAvailable = availableIndices.first else {
            for index in runtimes.indices {
                runtimes[index].isDefault = false
            }

            return
        }

        let existingDefault = availableIndices.first {
            runtimes[$0].isDefault
        }

        let selectedIndex = existingDefault ?? firstAvailable

        for index in runtimes.indices {
            runtimes[index].isDefault = index == selectedIndex
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

    case cannotRemoveExternalRuntime
    case runtimeRemovalFailed(String)

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

        case .cannotRemoveExternalRuntime:
            return "This Runtime is outside the Azeroth Launcher directory and cannot be deleted."

        case .runtimeRemovalFailed(let message):
            return "Failed to remove Wine Runtime: \(message)"
        }
    }
}
