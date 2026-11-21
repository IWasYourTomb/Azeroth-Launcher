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

    private(set) var isInstallingReleaseID: String?

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

    var availableReleases: [WineRuntimeRelease] {
        WineRuntimeCatalog.releases
    }

    func isInstalled(release: WineRuntimeRelease) -> Bool {
        let runtimeDirectory = managedRuntimesDirectory
            .appendingPathComponent(
                release.directoryName,
                isDirectory: true
            )

        let binDirectory = runtimeDirectory
            .appendingPathComponent("bin", isDirectory: true)

        let wineExecutable = binDirectory
            .appendingPathComponent("wine")

        let wineserverExecutable = binDirectory
            .appendingPathComponent("wineserver")

        let fileManager = FileManager.default

        return fileManager.isExecutableFile(
            atPath: wineExecutable.path
        ) && fileManager.isExecutableFile(
            atPath: wineserverExecutable.path
        )
    }

    func installedRuntime(for release: WineRuntimeRelease) -> WineRuntime? {
        let expectedExecutable = managedRuntimesDirectory
            .appendingPathComponent(
                release.directoryName,
                isDirectory: true
            )
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wine")
            .standardizedFileURL

        return runtimes.first {
            $0.executableURL.standardizedFileURL == expectedExecutable
        }
    }

    func installRuntime(release: WineRuntimeRelease) async throws {
        guard !isInstalling else {
            throw RuntimeError.installationInProgress
        }

        isInstalling = true
        isInstallingReleaseID = release.id
        installationError = nil

        defer {
            isInstalling = false
            isInstallingReleaseID = nil
        }

        do {

            if let existingRuntime = installedRuntime(for: release) {

                let validation = await validator.validate(
                    at: existingRuntime.runtimeDirectory
                )

                guard validation.isValid else {

                    throw RuntimeError.runtimeValidationFailed(
                        validation.error ?? "Unknown validation error."
                    )
                }

                try await register(existingRuntime)

                print(
                    "[WineRuntimeManager] Runtime already installed: \(existingRuntime.displayName)"
                )

                return
            }

            let runtime = try await installer.install(
                release: release
            )

            try await register(runtime)

            print(
                "[WineRuntimeManager] Installed: \(runtime.displayName)"
            )

        } catch {

            installationError = error.localizedDescription

            print(
                "[WineRuntimeManager] Installation failed: \(error.localizedDescription)"
            )

            throw error
        }
    }

    func register(_ runtime: WineRuntime) async throws {
        let executableURL = runtime.executableURL.standardizedFileURL

        guard executableURL.lastPathComponent == "wine",
              executableURL.deletingLastPathComponent().lastPathComponent == "bin" else {

            throw RuntimeError.invalidExecutable
        }

        let runtimeDirectory = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let validation = await validator.validate(
            at: runtimeDirectory
        )

        guard validation.isValid else {

            throw RuntimeError.runtimeValidationFailed(
                validation.error ?? "Unknown validation error."
            )
        }

        if let index = runtimes.firstIndex(
            where: {
                $0.executableURL.standardizedFileURL == executableURL
            }
        ) {

            runtimes[index].name = runtime.name

            runtimes[index].version =
                validation.version ?? runtime.version

            normalizeDefaultRuntime()
            save()

            print(
                "[WineRuntimeManager] Updated registration: \(runtimes[index].displayName)"
            )

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
        var errors: [String] = []

        for runtime in detectedRuntimes {

            do {

                try await register(runtime)
                registeredCount += 1

            } catch {

                let message = """
                \(runtime.displayName): \
                \(error.localizedDescription)
                """

                errors.append(message)

                print(
                    "[WineRuntimeManager] Registration failed: \(message)"
                )
            }
        }

        normalizeDefaultRuntime()
        save()

        if !errors.isEmpty {
            detectionError = errors.joined(separator: "\n")
        }

        print(
            "[WineRuntimeManager] Detection completed. Registered: \(registeredCount)"
        )
    }

    func refreshAvailability() async {
        for runtime in runtimes {

            let validation = await validator.validate(
                at: runtime.runtimeDirectory
            )

            if !validation.isValid {

                print(
                    """
                    [WineRuntimeManager] Runtime unavailable:
                    \(runtime.displayName)
                    \(validation.error ?? "Unknown error")
                    """
                )
            }
        }

        normalizeDefaultRuntime()
        save()
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

    func forget(id: UUID) {
        guard runtimes.contains(
            where: { $0.id == id }
        ) else {
            return
        }

        runtimes.removeAll {
            $0.id == id
        }

        normalizeDefaultRuntime()
        save()

        print(
            "[WineRuntimeManager] Runtime forgotten: \(id)"
        )
    }

    func remove(id: UUID) {
        forget(id: id)
    }

    func canRemoveFromDisk(_ runtime: WineRuntime) -> Bool {
        guard runtime.executableURL.lastPathComponent == "wine",
              runtime.executableURL
                .deletingLastPathComponent()
                .lastPathComponent == "bin" else {
            return false
        }

        let runtimeDirectory = runtime.runtimeDirectory

        let managedDirectory = managedRuntimesDirectory

        let resolvedRuntimeDirectory = runtimeDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL

        let resolvedManagedDirectory = managedDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL

        guard resolvedRuntimeDirectory
            .deletingLastPathComponent()
            == resolvedManagedDirectory else {
            return false
        }

        if let values = try? runtimeDirectory.resourceValues(
            forKeys: [.isSymbolicLinkKey]
        ), values.isSymbolicLink == true {
            return false
        }

        return true
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

        let runtimeDirectory = runtime.runtimeDirectory

        let fileManager = FileManager.default

        if fileManager.fileExists(
            atPath: runtimeDirectory.path
        ) {

            do {

                try await Task.detached(
                    priority: .utility
                ) {

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

            runtimes[index].isDefault =
                index == selectedIndex
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

    case runtimeValidationFailed(String)

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
        case .runtimeValidationFailed(let message):
            return "Wine Runtime validation failed: \(message)"
        case .cannotRemoveExternalRuntime:
            return """
            This Runtime is outside the Azeroth Launcher directory \
            and cannot be deleted.
            """
        case .runtimeRemovalFailed(let message):
            return "Failed to remove Wine Runtime: \(message)"
        }
    }
}
