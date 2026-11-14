//
//  RendererInstaller.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import Foundation
import CryptoKit

final class RendererInstaller {

    private let fileManager = FileManager.default
    private let rendererPath = "Renderers/MTLD3D/Cataclysm"

    private let expectedRenderer = "MTLD3D"
    private let expectedVersion = "0.7.0"

    enum InstallResult {
        case installed
        case alreadyInstalled
        case restored
    }

    enum InstallerError: LocalizedError {
        case resourcesNotFound
        case manifestNotFound
        case invalidManifest
        case unsupportedRenderer
        case dllNotFound
        case checksumMismatch
        case prefixNotFound

        var errorDescription: String? {
            switch self {
            case .resourcesNotFound:
                return "MTLD3D resources were not found."
            case .manifestNotFound:
                return "Renderer manifest was not found."
            case .invalidManifest:
                return "Renderer manifest is invalid."
            case .unsupportedRenderer:
                return "Unsupported renderer version."
            case .dllNotFound:
                return "Renderer DLL was not found."
            case .checksumMismatch:
                return "Renderer DLL checksum verification failed."
            case .prefixNotFound:
                return "Wine prefix was not found."
            }
        }
    }

    private struct Manifest: Decodable {
        let renderer: String
        let rendererVersion: String
        let patchVersion: String
        let component: String
        let architecture: String
        let clientBuild: String
        let files: [ManifestFile]
    }

    private struct ManifestFile: Decodable {
        let name: String
        let destination: String
        let sha256: String
    }


    func installCataclysmMTLD3D(in prefixURL: URL) throws -> InstallResult {

        guard fileManager.fileExists(atPath: prefixURL.path) else {
            throw InstallerError.prefixNotFound
        }

        let resourcesURL = try getResourcesURL()

        let manifest = try loadManifest(
            from: resourcesURL
        )

        try validateManifest(manifest)

        guard let dll = manifest.files.first(
            where: { $0.name == "d3d9.dll" }
        ) else {
            throw InstallerError.dllNotFound
        }

        let sourceURL = resourcesURL.appendingPathComponent(
            dll.name
        )

        try verifyChecksum(
            of: sourceURL,
            expected: dll.sha256
        )

        let destinationURL = prefixURL
            .appendingPathComponent("drive_c")
            .appendingPathComponent("windows")
            .appendingPathComponent("syswow64")
            .appendingPathComponent(dll.name)

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            if try checksum(of: destinationURL) == dll.sha256.lowercased() {
                return .alreadyInstalled
            }
        }

        let backupURL = destinationURL
            .appendingPathExtension("azeroth-backup")

        if fileManager.fileExists(atPath: destinationURL.path),
           !fileManager.fileExists(atPath: backupURL.path) {

            try fileManager.copyItem(
                at: destinationURL,
                to: backupURL
            )
        }

        let sourceData = try Data(contentsOf: sourceURL)

        try sourceData.write(
            to: destinationURL,
            options: .atomic
        )

        try verifyChecksum(
            of: destinationURL,
            expected: dll.sha256
        )

        return .installed
    }

    
    private func getResourcesURL() throws -> URL {
        guard let resourcesURL = Bundle.main.resourceURL else {
            throw RendererInstaller.InstallerError.dllNotFound
        }

        return resourcesURL
    }

    private func loadManifest(from directory: URL) throws -> Manifest {

        let manifestURL = directory.appendingPathComponent(
            "manifest.json"
        )

        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw InstallerError.manifestNotFound
        }

        let data = try Data(contentsOf: manifestURL)

        do {
            return try JSONDecoder().decode(
                Manifest.self,
                from: data
            )
        } catch {
            throw InstallerError.invalidManifest
        }
    }

    private func validateManifest(_ manifest: Manifest) throws {

        guard manifest.renderer == expectedRenderer,
              manifest.rendererVersion == expectedVersion,
              manifest.component == "Cataclysm",
              manifest.clientBuild == "4.3.4.15595",
              manifest.architecture == "i386" else {
            throw InstallerError.unsupportedRenderer
        }
    }

    private func checksum(of url: URL) throws -> String {

        let data = try Data(contentsOf: url)

        let digest = SHA256.hash(data: data)

        return digest
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func verifyChecksum(of url: URL, expected: String) throws {

        guard fileManager.fileExists(atPath: url.path) else {
            throw InstallerError.dllNotFound
        }

        let actual = try checksum(of: url)

        guard actual == expected.lowercased() else {
            throw InstallerError.checksumMismatch
        }
    }
}
