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

    init(
        fileManager: FileManager = .default,
        prefixManager: PrefixManager = PrefixManager(),
        homeManager: WineHomeManager = WineHomeManager()
    ) {
        self.fileManager = fileManager
        self.prefixManager = prefixManager
        self.homeManager = homeManager
    }

    func validate(installation: GameInstallation, runtime: WineRuntime,renderer: RendererType) async -> EnvironmentValidationReport {

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

    private func validateRuntime(_ runtime: WineRuntime,into checks: inout [EnvironmentCheckResult]) {

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

    private func validatePrefix(_ installation: GameInstallation,into checks: inout [EnvironmentCheckResult]) async {

        let prefixURL = installation.prefixPath

        guard fileManager.fileExists(
            atPath: prefixURL.path
        ) else {

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
            at: installation.prefixPath
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

        let exists = fileManager.fileExists(
            atPath: executableURL.path
        )

        let readable = fileManager.isReadableFile(
            atPath: executableURL.path
        )

        let status: EnvironmentCheckStatus =
            exists && readable ? .ready : .error

        append(
            id: "game-executable",
            title: "WoW Executable",
            details: executableURL.path,
            status: status,
            into: &checks
        )
    }

    private func validateWineHome(into checks: inout [EnvironmentCheckResult]){

        let wineDirectory = homeManager.wineDirectory

        let exists = fileManager.fileExists(
            atPath: wineDirectory.path
        )

        append(
            id: "wine-home",
            title: "Wine Home",
            details: wineDirectory.path,
            status: exists ? .ready : .warning,
            into: &checks
        )
    }

    private func validateRenderer(runtime: WineRuntime, renderer: RendererType, into checks: inout [EnvironmentCheckResult]) {
        switch renderer {
        case .dxvk:
            let runtimeDirectory = runtime.executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let icdManifest = runtimeDirectory
                .appendingPathComponent(
                    "lib/vulkan/icd.d/MoltenVK_icd.json"
                )

            let icdExists = fileManager.fileExists(
                atPath: icdManifest.path
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

        case .metal:
            append(
                id: "metal-renderer",
                title: "Metal Renderer",
                details: "MTLD3D component validation is not implemented yet.",
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
