//
//  EnvironmentValidator.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import Foundation

@MainActor
final class EnvironmentValidator {

    private let fileManager: FileManager
    private let prefixManager: PrefixManager
    private let homeManager: WineHomeManager
    private let rendererInstaller: RendererInstaller

    init(
        fileManager: FileManager = .default,
        prefixManager: PrefixManager = PrefixManager(),
        homeManager: WineHomeManager = WineHomeManager(),
        rendererInstaller: RendererInstaller = RendererInstaller()
    ) {
        self.fileManager = fileManager
        self.prefixManager = prefixManager
        self.homeManager = homeManager
        self.rendererInstaller = rendererInstaller
    }

    func validate(installation: GameInstallation, runtime: WineRuntime, renderer: RendererType) async -> EnvironmentValidationReport{
        var checks: [EnvironmentCheckResult] = []

        validateRuntime(
            runtime,
            into: &checks
        )

        await validatePrefix(
            installation,
            into: &checks
        )

        validateGameExecutable(
            installation,
            into: &checks
        )

        validateWineHome(
            into: &checks
        )

        validateRenderer(
            installation: installation,
            runtime: runtime,
            renderer: renderer,
            into: &checks
        )

        validateSidecar(
            into: &checks
        )

        return EnvironmentValidationReport(
            installationID: installation.id,
            checks: checks
        )
    }

    private func validateRuntime(_ runtime: WineRuntime, into checks: inout [EnvironmentCheckResult]    ) {
        let wineURL = runtime.executableURL

        append(
            id: "wine",
            title: "Wine Runtime",
            details: runtime.displayName,
            status: fileManager.isExecutableFile(
                atPath: wineURL.path
            ) ? .ready : .error,
            into: &checks
        )

        let runtimeDirectory = wineURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let wineserverURL = runtimeDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("wineserver")

        append(
            id: "wineserver",
            title: "Wine Server",
            details: wineserverURL.path,
            status: fileManager.isExecutableFile(
                atPath: wineserverURL.path
            ) ? .ready : .error,
            into: &checks
        )
    }
    private func validatePrefix(_ installation: GameInstallation, into checks: inout [EnvironmentCheckResult]) async {
        let prefixURL = installation.prefixPath

        guard isDirectory(at: prefixURL) else {

            append(
                id: "prefix",
                title: "Wine Prefix",
                details: prefixURL.path,
                status: .error,
                into: &checks
            )

            return
        }

        append(
            id: "prefix",
            title: "Wine Prefix",
            details: prefixURL.path,
            status: .ready,
            into: &checks
        )

        let validation = await prefixManager.validate(
            at: prefixURL
        )

        append(
            id: "prefix-structure",
            title: "Prefix Structure",
            details: validation.isValid
                ? "Prefix structure is valid."
                : "Prefix structure validation failed: \(validation.issues)",
            status: validation.isValid ? .ready : .error,
            into: &checks
        )
    }

    private func validateGameExecutable(_ installation: GameInstallation, into checks: inout [EnvironmentCheckResult]) {
        let executableURL = installation.installationPath
            .appendingPathComponent("Wow.exe")

        let isRegularFile = self.isRegularFile(
            at: executableURL
        )

        let readable = fileManager.isReadableFile(
            atPath: executableURL.path
        )

        append(
            id: "game-executable",
            title: "WoW Executable",
            details: executableURL.path,
            status: isRegularFile && readable ? .ready : .error,
            into: &checks
        )
    }

    private func validateWineHome(into checks: inout [EnvironmentCheckResult]) {
        let wineDirectory = homeManager.wineDirectory

        let exists = isDirectory(
            at: wineDirectory
        )

        let writable = exists && fileManager.isWritableFile(
            atPath: wineDirectory.path
        )

        let status: EnvironmentCheckStatus

        if !exists {
            status = .warning
        } else if !writable {
            status = .error
        } else {
            status = .ready
        }

        let details: String

        if !exists {
            details = "Wine Home directory has not been created yet."
        } else if !writable {
            details = "Wine Home directory is not writable."
        } else {
            details = wineDirectory.path
        }

        append(
            id: "wine-home",
            title: "Wine Home",
            details: details,
            status: status,
            into: &checks
        )
    }

    private func validateRenderer(
        installation: GameInstallation,
        runtime: WineRuntime,
        renderer: RendererType,
        into checks: inout [EnvironmentCheckResult]
    ) {

        switch renderer {
        case .dxvk:
            validateDXVK(
                runtime: runtime,
                into: &checks
            )

        case .metal:
            validateMetalRenderer(
                installation: installation,
                into: &checks
            )
        }
    }

    private func validateDXVK(runtime: WineRuntime, into checks: inout [EnvironmentCheckResult]) {
        let runtimeDirectory = runtime.executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let icdManifest = runtimeDirectory
            .appendingPathComponent(
                "lib/vulkan/icd.d/MoltenVK_icd.json"
            )

        let icdExists = isRegularFile(
            at: icdManifest
        )

        append(
            id: "vulkan-icd",
            title: "MoltenVK Vulkan ICD",
            details: icdManifest.path,
            status: icdExists ? .ready : .error,
            into: &checks
        )

        append(
            id: "dxvk",
            title: "DXVK Components",
            details: "DXVK installation validation is not implemented yet.",
            status: .warning,
            into: &checks
        )
    }

    private func validateMetalRenderer(installation: GameInstallation,into checks: inout [EnvironmentCheckResult]) {
        guard installation.edition == .cataclysm else {
            append(
                id: "metal-renderer",
                title: "MTLD3D Renderer",
                details: "MTLD3D is not required for this game edition.",
                status: .ready,
                into: &checks
            )
            return
        }

        do {
            let installed = try rendererInstaller.isInstalled(
                in: installation.prefixPath
            )

            append(
                id: "metal-renderer",
                title: "MTLD3D Renderer",
                details: installed
                    ? "MTLD3D 0.7.0 is installed and checksum is valid."
                    : "MTLD3D 0.7.0 will be installed or repaired before launch.",
                status: installed ? .ready : .warning,
                into: &checks
            )

        } catch {
            append(
                id: "metal-renderer",
                title: "MTLD3D Renderer",
                details: "Renderer will be checked during launch: \(error.localizedDescription)",
                status: .warning,
                into: &checks
            )
        }
    }

    private func validateSidecar(into checks: inout [EnvironmentCheckResult]) {
        let sidecarURL = Bundle.main.resourceURL?
            .appendingPathComponent("x87sidecar")

        guard let sidecarURL else {

            append(
                id: "sidecar",
                title: "x87 Sidecar",
                details: "Application resources directory is unavailable.",
                status: .warning,
                into: &checks
            )

            return
        }

        let executable = fileManager.isExecutableFile(
            atPath: sidecarURL.path
        )

        append(
            id: "sidecar",
            title: "x87 Sidecar",
            details: sidecarURL.path,
            status: executable ? .ready : .warning,
            into: &checks
        )
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        return fileManager.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
    }

    private func isRegularFile(at url: URL) -> Bool {

        guard let attributes = try? fileManager.attributesOfItem(
            atPath: url.path
        ) else {
            return false
        }

        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private func append(
        id: String,
        title: String,
        details: String,
        status: EnvironmentCheckStatus,
        into checks: inout [EnvironmentCheckResult]
    ) {
        checks.append(
            EnvironmentCheckResult(
                id: id,
                title: title,
                details: details,
                status: status
            )
        )
    }
}
