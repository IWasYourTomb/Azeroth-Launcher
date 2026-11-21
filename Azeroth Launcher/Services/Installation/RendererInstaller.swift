//
//  RendererInstaller.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import Foundation
import CryptoKit

final class RendererInstaller {
    private let fileManager: FileManager
    private let rendererPath = "Renderers/MTLD3D/Cataclysm"

    private let expectedRenderer = "MTLD3D"
    private let expectedVersion = "0.7.0"
    private let expectedPatchVersion = "1.0.0"
    private let expectedComponent = "Cataclysm"
    private let expectedClientBuild = "4.3.4.15595"
    private let expectedArchitecture = "i386"

    private let manifestFileName = "manifest.json"
    private let backupExtension = "azeroth-backup"

    private let stateDirectoryName = ".azeroth-renderer"
    private let stateFileName = "mtld3d-cataclysm.json"

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

        case invalidManifestFile(String)
        case duplicateManifestEntry(String)

        case dllNotFound
        case checksumMismatch
        case prefixNotFound

        case backupNotFound(String)
        case destinationInvalid(String)
        case stateInvalid

        var errorDescription: String? {
            switch self {

            case .resourcesNotFound:
                return "Renderer resources were not found."

            case .manifestNotFound:
                return "Renderer manifest was not found."

            case .invalidManifest:
                return "Renderer manifest is invalid."

            case .unsupportedRenderer:
                return "Unsupported renderer version."

            case .invalidManifestFile(let name):
                return "Invalid renderer manifest file: \(name)"

            case .duplicateManifestEntry(let name):
                return "Duplicate renderer manifest entry: \(name)"

            case .dllNotFound:
                return "Renderer DLL was not found."

            case .checksumMismatch:
                return "Renderer file checksum verification failed."

            case .prefixNotFound:
                return "Wine prefix was not found."

            case .backupNotFound(let path):
                return "Original file backup was not found: \(path)"

            case .destinationInvalid(let path):
                return "Invalid renderer destination: \(path)"

            case .stateInvalid:
                return "Renderer installation state is invalid."
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

    private struct InstallationState: Codable {
        let renderer: String
        let rendererVersion: String
        let patchVersion: String

        let files: [InstalledFileState]
    }

    private struct InstalledFileState: Codable {
        let name: String
        let destination: String
        let originalExisted: Bool
    }


    private struct ResolvedFile {
        let manifestFile: ManifestFile
        let sourceURL: URL
        let destinationURL: URL
    }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func installCataclysmMTLD3D(in prefixURL: URL) throws -> InstallResult {
        try validatePrefix(prefixURL)

        let resourcesURL = try getResourcesURL()

        let manifest = try loadManifest(
            from: resourcesURL
        )

        try validateManifest(manifest)

        let files = try resolveManifestFiles(
            manifest,
            resourcesURL: resourcesURL,
            prefixURL: prefixURL
        )

        guard !files.isEmpty else {
            throw InstallerError.invalidManifest
        }

        if try isInstalled(files: files) {
            return .alreadyInstalled
        }

        let state = try prepareInstallationState(
            files: files,
            manifest: manifest,
            prefixURL: prefixURL
        )

        try saveInstallationState(
            state,
            in: prefixURL
        )

        for file in files {
            try installFile(
                file,
                prefixURL: prefixURL
            )
        }

        guard try isInstalled(files: files) else {
            throw InstallerError.checksumMismatch
        }

        return .installed
    }

    func isInstalled(in prefixURL: URL) throws -> Bool {
        try validatePrefix(prefixURL)

        let resourcesURL = try getResourcesURL()

        let manifest = try loadManifest(
            from: resourcesURL
        )

        try validateManifest(manifest)

        let files = try resolveManifestFiles(
            manifest,
            resourcesURL: resourcesURL,
            prefixURL: prefixURL
        )

        return try isInstalled(files: files)
    }

    private func isInstalled(files: [ResolvedFile]) throws -> Bool {
        guard !files.isEmpty else {
            return false
        }

        for file in files {

            guard isRegularFile(
                at: file.destinationURL
            ) else {
                return false
            }

            let actualChecksum = try checksum(
                of: file.destinationURL
            )

            guard actualChecksum == file.manifestFile.sha256.lowercased() else {
                return false
            }
        }

        return true
    }

    func restoreOriginal(in prefixURL: URL) throws -> InstallResult {
        try validatePrefix(prefixURL)

        let resourcesURL = try getResourcesURL()

        let manifest = try loadManifest(
            from: resourcesURL
        )

        try validateManifest(manifest)

        let files = try resolveManifestFiles(
            manifest,
            resourcesURL: resourcesURL,
            prefixURL: prefixURL
        )

        guard !files.isEmpty else {
            throw InstallerError.invalidManifest
        }

        let state = try loadInstallationState(
            in: prefixURL
        )

        let originalStates = try resolveOriginalStates(
            files: files,
            state: state
        )

        for file in files {
            guard let originalExisted = originalStates[file.manifestFile.destination] else {
                throw InstallerError.stateInvalid
            }

            guard originalExisted else {
                continue
            }

            let backupURL = backupURL(
                for: file.destinationURL
            )

            guard isRegularFile(at: backupURL) else {
                throw InstallerError.backupNotFound(
                    backupURL.path
                )
            }
        }

        for file in files {
            guard let originalExisted = originalStates[file.manifestFile.destination] else {
                throw InstallerError.stateInvalid
            }

            if originalExisted {
                let backupURL = backupURL(
                    for: file.destinationURL
                )

                let backupData = try Data(
                    contentsOf: backupURL
                )

                try backupData.write(
                    to: file.destinationURL,
                    options: .atomic
                )

            } else {
                
                if isSymbolicLink(at: file.destinationURL) {
                    throw InstallerError.destinationInvalid(
                        file.destinationURL.path
                    )
                }

                if fileManager.fileExists(
                    atPath: file.destinationURL.path
                ) {

                    guard isRegularFile(at: file.destinationURL) else {
                        throw InstallerError.destinationInvalid(
                            file.destinationURL.path
                        )
                    }

                    try fileManager.removeItem(
                        at: file.destinationURL
                    )
                }
            }
        }

        for file in files {
            let backupURL = backupURL(
                for: file.destinationURL
            )

            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(
                    at: backupURL
                )
            }
        }

        try removeInstallationState(
            in: prefixURL
        )

        return .restored
    }

    private func prepareInstallationState(files: [ResolvedFile], manifest: Manifest, prefixURL: URL) throws -> InstallationState {
        let existingState = try loadInstallationStateIfExists(
            in: prefixURL
        )

        if let existingState {

            guard existingState.renderer == manifest.renderer,
                  existingState.rendererVersion == manifest.rendererVersion,
                  existingState.patchVersion == manifest.patchVersion else {
                throw InstallerError.stateInvalid
            }

            return existingState
        }

        var states: [InstalledFileState] = []

        for file in files {

            let destinationURL = file.destinationURL

            let exists = fileManager.fileExists(
                atPath: destinationURL.path
            )

            if exists && !isRegularFile(at: destinationURL) {
                throw InstallerError.destinationInvalid(
                    destinationURL.path
                )
            }

            let backupURL = backupURL(
                for: destinationURL
            )

            let backupExists = isRegularFile(
                at: backupURL
            )

            let originalExisted = exists || backupExists

            if backupExists && !exists {
            } else if exists && !backupExists {

                try fileManager.copyItem(
                    at: destinationURL,
                    to: backupURL
                )
            }

            states.append(
                InstalledFileState(
                    name: file.manifestFile.name,
                    destination: file.manifestFile.destination,
                    originalExisted: originalExisted
                )
            )
        }

        return InstallationState(
            renderer: manifest.renderer,
            rendererVersion: manifest.rendererVersion,
            patchVersion: manifest.patchVersion,
            files: states
        )
    }

    private func resolveOriginalStates(files: [ResolvedFile], state: InstallationState?) throws -> [String: Bool] {
        guard let state else {
            var result: [String: Bool] = [:]

            for file in files {

                let backupURL = backupURL(
                    for: file.destinationURL
                )

                result[file.manifestFile.destination] =
                    isRegularFile(at: backupURL)
            }

            return result
        }

        guard state.renderer == expectedRenderer,
              state.rendererVersion == expectedVersion,
              state.patchVersion == expectedPatchVersion else {
            throw InstallerError.stateInvalid
        }

        var result: [String: Bool] = [:]

        for file in files {

            guard let savedFile = state.files.first(
                where: {
                    $0.destination == file.manifestFile.destination
                    && $0.name == file.manifestFile.name
                }
            ) else {
                throw InstallerError.stateInvalid
            }

            result[file.manifestFile.destination] =
                savedFile.originalExisted
        }

        return result
    }

    private func saveInstallationState(_ state: InstallationState, in prefixURL: URL) throws {
        let directoryURL = stateDirectoryURL(
            in: prefixURL
        )

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(state)

        try data.write(
            to: stateFileURL(in: prefixURL),
            options: .atomic
        )
    }

    private func loadInstallationState(in prefixURL: URL) throws -> InstallationState? {

        try loadInstallationStateIfExists(
            in: prefixURL
        )
    }

    private func loadInstallationStateIfExists(in prefixURL: URL) throws -> InstallationState? {
        let url = stateFileURL(
            in: prefixURL
        )

        guard fileManager.fileExists(
            atPath: url.path
        ) else {
            return nil
        }

        guard isRegularFile(at: url) else {
            throw InstallerError.stateInvalid
        }

        do {
            let data = try Data(contentsOf: url)

            return try JSONDecoder().decode(
                InstallationState.self,
                from: data
            )
        } catch {
            throw InstallerError.stateInvalid
        }
    }

    private func removeInstallationState(in prefixURL: URL) throws {
        let directoryURL = stateDirectoryURL(
            in: prefixURL
        )

        if fileManager.fileExists(
            atPath: directoryURL.path
        ) {
            try fileManager.removeItem(
                at: directoryURL
            )
        }
    }

    private func stateDirectoryURL(in prefixURL: URL) -> URL {
        prefixURL.appendingPathComponent(
            stateDirectoryName,
            isDirectory: true
        )
    }

    private func stateFileURL(in prefixURL: URL) -> URL {
        stateDirectoryURL(in: prefixURL)
            .appendingPathComponent(stateFileName)
    }

    private func installFile(_ file: ResolvedFile, prefixURL: URL) throws {
        let sourceURL = file.sourceURL
        let destinationURL = file.destinationURL

        guard isRegularFile(at: sourceURL) else {
            throw InstallerError.dllNotFound
        }

        try verifyChecksum(
            of: sourceURL,
            expected: file.manifestFile.sha256
        )

        try validateDestinationPath(
            file.manifestFile.destination,
            inside: prefixURL
        )

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if isRegularFile(at: destinationURL) {

            let currentChecksum = try checksum(
                of: destinationURL
            )

            if currentChecksum == file.manifestFile.sha256.lowercased() {
                return
            }
        }

        let sourceData = try Data(
            contentsOf: sourceURL
        )

        try sourceData.write(
            to: destinationURL,
            options: .atomic
        )

        try verifyChecksum(
            of: destinationURL,
            expected: file.manifestFile.sha256
        )
    }

    private func loadManifest(from directory: URL) throws -> Manifest {
        let manifestURL = directory.appendingPathComponent(
            manifestFileName
        )

        guard isRegularFile(at: manifestURL) else {
            throw InstallerError.manifestNotFound
        }

        let data = try Data(
            contentsOf: manifestURL
        )

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
              manifest.patchVersion == expectedPatchVersion,
              manifest.component == expectedComponent,
              manifest.clientBuild == expectedClientBuild,
              manifest.architecture == expectedArchitecture else {

            throw InstallerError.unsupportedRenderer
        }

        guard !manifest.files.isEmpty else {
            throw InstallerError.invalidManifest
        }

        var names = Set<String>()
        var destinations = Set<String>()

        for file in manifest.files {

            guard isValidFileName(file.name),
                  isValidRelativePath(file.destination),
                  isValidChecksum(file.sha256) else {

                throw InstallerError.invalidManifestFile(
                    file.name
                )
            }

            guard names.insert(file.name).inserted else {
                throw InstallerError.duplicateManifestEntry(
                    file.name
                )
            }

            guard destinations.insert(file.destination).inserted else {
                throw InstallerError.duplicateManifestEntry(
                    file.destination
                )
            }
        }
    }

    private func resolveManifestFiles(_ manifest: Manifest, resourcesURL: URL, prefixURL: URL) throws -> [ResolvedFile] {
        var result: [ResolvedFile] = []

        for file in manifest.files {

            let sourceURL = resourcesURL
                .appendingPathComponent(file.name)

            let destinationURL = try resolveDestination(
                file.destination,
                inside: prefixURL
            )

            guard isRegularFile(at: sourceURL) else {
                throw InstallerError.dllNotFound
            }

            result.append(
                ResolvedFile(
                    manifestFile: file,
                    sourceURL: sourceURL,
                    destinationURL: destinationURL
                )
            )
        }

        return result
    }


    private func getResourcesURL() throws -> URL {
        guard let resourcesURL = Bundle.main.resourceURL else {
            throw InstallerError.resourcesNotFound
        }

        let rendererDirectory = resourcesURL
            .appendingPathComponent(
                rendererPath,
                isDirectory: true
            )

        guard fileManager.fileExists(
            atPath: rendererDirectory.path
        ) else {
            throw InstallerError.resourcesNotFound
        }

        return rendererDirectory
    }

    private func resolveDestination(_ relativePath: String, inside root: URL) throws -> URL {
        guard isValidRelativePath(relativePath) else {
            throw InstallerError.destinationInvalid(
                relativePath
            )
        }

        let rootURL = root
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let destinationURL = rootURL
            .appendingPathComponent(relativePath)
            .standardizedFileURL

        let rootPath = rootURL.path + "/"
        let destinationPath = destinationURL.path

        guard destinationPath.hasPrefix(rootPath) else {
            throw InstallerError.destinationInvalid(
                relativePath
            )
        }

        try validateDestinationPath(
            relativePath,
            inside: rootURL
        )

        return destinationURL
    }

    private func validateDestinationPath(_ relativePath: String, inside root: URL) throws {
        let rootURL = root
            .standardizedFileURL
            .resolvingSymlinksInPath()

        var currentURL = rootURL

        let components = relativePath.split(
            separator: "/"
        )

        for (index, component) in components.enumerated() {
            currentURL.appendPathComponent(
                String(component)
            )

            if isSymbolicLink(at: currentURL) {
                throw InstallerError.destinationInvalid(
                    currentURL.path
                )
            }

            if fileManager.fileExists(
                atPath: currentURL.path
            ) {

                var isDirectory: ObjCBool = false

                guard fileManager.fileExists(
                    atPath: currentURL.path,
                    isDirectory: &isDirectory
                ) else {
                    throw InstallerError.destinationInvalid(
                        currentURL.path
                    )
                }

                let isLastComponent = index == components.count - 1

                if !isLastComponent && !isDirectory.boolValue {
                    throw InstallerError.destinationInvalid(
                        currentURL.path
                    )
                }
            }
        }
    }

    private func isValidFileName(_ name: String) -> Bool {
        !name.isEmpty
        && name != "."
        && name != ".."
        && !name.contains("/")
        && !name.contains("\\")
    }

    private func isValidRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\") else {
            return false
        }

        let components = path.split(
            separator: "/"
        )

        guard !components.isEmpty else {
            return false
        }

        return components.allSatisfy {
            $0 != "." && $0 != ".."
        }
    }

    private func validatePrefix(_ prefixURL: URL) throws {
        guard isDirectory(at: prefixURL) else {
            throw InstallerError.prefixNotFound
        }
    }

    private func isDirectory(at url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(
            atPath: url.path
        ) else {
            return false
        }

        return attributes[.type] as? FileAttributeType == .typeDirectory
    }

    private func isRegularFile(at url: URL) -> Bool {
        guard !isSymbolicLink(at: url),
              let attributes = try? fileManager.attributesOfItem(
                atPath: url.path
              ) else {
            return false
        }

        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private func isSymbolicLink(at url: URL) -> Bool {

        (try? fileManager.destinationOfSymbolicLink(
            atPath: url.path
        )) != nil
    }

    private func backupURL(for destinationURL: URL) -> URL {
        destinationURL.appendingPathExtension(
            backupExtension
        )
    }

    private func checksum(of url: URL) throws -> String {
        let data = try Data(
            contentsOf: url
        )

        let digest = SHA256.hash(
            data: data
        )

        return digest
            .map {
                String(format: "%02x", $0)
            }
            .joined()
    }

    private func isValidChecksum(_ checksum: String) -> Bool {
        checksum.count == 64
        && checksum.allSatisfy {
            $0.isHexDigit
        }
    }

    private func verifyChecksum(of url: URL, expected: String) throws {
        guard isRegularFile(at: url) else {
            throw InstallerError.dllNotFound
        }

        let actual = try checksum(
            of: url
        )

        guard actual == expected.lowercased() else {
            throw InstallerError.checksumMismatch
        }
    }
}
