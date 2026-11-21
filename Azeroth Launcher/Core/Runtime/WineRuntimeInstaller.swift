//
//  WineRuntimeInstaller.swift
//  Azeroth Launcher
//

import Foundation
import CryptoKit
import Darwin

actor WineRuntimeInstaller {
    private let quarantineAttribute = "com.apple.quarantine"

    private var applicationSupportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AzerothLauncher", isDirectory: true)
    }

    private var runtimesDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("Runtimes", isDirectory: true)
    }

    private var downloadsDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    private func runtimeDirectory(for release: WineRuntimeRelease) -> URL {
        runtimesDirectory
            .appendingPathComponent(release.directoryName, isDirectory: true)
    }

    private func stagingDirectory(for release: WineRuntimeRelease) -> URL {
        runtimesDirectory
            .appendingPathComponent(
                release.stagingDirectoryName,
                isDirectory: true
            )
    }

    private func archiveURL(for release: WineRuntimeRelease) -> URL {
        downloadsDirectory
            .appendingPathComponent(release.archiveFileName)
    }

    private func wineExecutable(for release: WineRuntimeRelease) -> URL {
        runtimeDirectory(for: release)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wine")
    }

    private func wineserverExecutable(for release: WineRuntimeRelease) -> URL {
        runtimeDirectory(for: release)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wineserver")
    }

    func install(release: WineRuntimeRelease) async throws -> WineRuntime {

        print("[WineRuntimeInstaller] Starting installation")
        print("[WineRuntimeInstaller] Release: \(release.displayName)")
        print("[WineRuntimeInstaller] Directory: \(release.directoryName)")

        let destination = runtimeDirectory(for: release)
        
        if FileManager.default.fileExists(atPath: destination.path) {

            if isInstalled(release: release) {
                print("[WineRuntimeInstaller] Runtime already installed")

                return makeRuntime(release: release)
            }

            print("[WineRuntimeInstaller] Existing Runtime is invalid")

            throw InstallerError.existingRuntimeInvalid(
                destination.path
            )
        }

        do {

            try createDirectories()

            try diagnoseQuarantineExclusion()

            try downloadRuntime(release: release)

            try verifyChecksum(release: release)

            print("[WineRuntimeInstaller] Checking archive quarantine...")

            let archive = archiveURL(for: release)

            if hasQuarantineAttribute(at: archive) {
                print("[WineRuntimeInstaller] WARNING: Archive contains quarantine attribute")
            } else {
                print("[WineRuntimeInstaller] Archive has no quarantine attribute")
            }

            try extractRuntime(release: release)

            try validateRuntime(at: stagingDirectory(for: release))

            try diagnoseExtractedQuarantine(release: release)

            try setExecutablePermissions(release: release)

            try diagnoseRuntime(release: release)

            try installStagingRuntime(release: release)

            print("[WineRuntimeInstaller] Installation completed successfully")

            return makeRuntime(release: release)

        } catch {
            let staging = stagingDirectory(for: release)

            if FileManager.default.fileExists(atPath: staging.path) {
                try? FileManager.default.removeItem(at: staging)
            }

            print(
                "[WineRuntimeInstaller] Installation failed: \(error.localizedDescription)"
            )

            throw error
        }
    }
    
    func install() async throws -> WineRuntime {
        try await install(release: .r17)
    }

    private func createDirectories() throws {
        let fileManager = FileManager.default

        try fileManager.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        try fileManager.createDirectory(
            at: downloadsDirectory,
            withIntermediateDirectories: true
        )

        try fileManager.createDirectory(
            at: runtimesDirectory,
            withIntermediateDirectories: true
        )

        print(
            "[WineRuntimeInstaller] Application directory: \(applicationSupportDirectory.path)"
        )
    }

    private func diagnoseQuarantineExclusion() throws {

        let probeURL = downloadsDirectory
            .appendingPathComponent("quarantine-probe.txt")

        try? FileManager.default.removeItem(at: probeURL)

        try Data("Azeroth Launcher quarantine test".utf8)
            .write(to: probeURL, options: .atomic)

        let quarantined = hasQuarantineAttribute(at: probeURL)

        print("[WineRuntimeInstaller] === Quarantine exclusion test ===")
        print("[WineRuntimeInstaller] Probe: \(probeURL.path)")
        print("[WineRuntimeInstaller] App-created file quarantined: \(quarantined)")

        if quarantined {
            print("[WineRuntimeInstaller] WARNING: App-created file has quarantine")
        } else {
            print("[WineRuntimeInstaller] App-created file has no quarantine")
        }
    }

    private func diagnoseExtractedQuarantine(release: WineRuntimeRelease) throws {

        let staging = stagingDirectory(for: release)

        print("[WineRuntimeInstaller] === Extracted quarantine diagnostics ===")

        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: staging,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            throw InstallerError.invalidRuntime
        }

        var quarantinedFiles = 0
        var checkedFiles = 0

        for case let fileURL as URL in enumerator {

            checkedFiles += 1

            if hasQuarantineAttribute(at: fileURL) {
                quarantinedFiles += 1

                print(
                    "[WineRuntimeInstaller] QUARANTINE FOUND: \(fileURL.path)"
                )
            }
        }

        print("[WineRuntimeInstaller] Checked files: \(checkedFiles)")
        print("[WineRuntimeInstaller] Quarantined files: \(quarantinedFiles)")
    }

    private func hasQuarantineAttribute(at url: URL) -> Bool {

        let result = url.path.withCString { path in
            quarantineAttribute.withCString { attributeName in
                Darwin.getxattr(
                    path,
                    attributeName,
                    nil,
                    0,
                    0,
                    0
                )
            }
        }

        return result >= 0
    }

    private func downloadRuntime(release: WineRuntimeRelease) throws {
        let archive = archiveURL(for: release)

        print("[WineRuntimeInstaller] Downloading Wine Runtime using curl...")
        print("[WineRuntimeInstaller] URL: \(release.downloadURL)")
        print("[WineRuntimeInstaller] Archive path: \(archive.path)")

        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: archive.path) {
            try fileManager.removeItem(at: archive)
        }

        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")

        process.arguments = [
            "--fail",
            "--location",
            "--silent",
            "--show-error",
            "--connect-timeout", "30",
            "--max-time", "900",
            "--retry", "2",
            "--output", archive.path,
            "--write-out", "%{http_code}",
            release.downloadURL.absoluteString
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("[WineRuntimeInstaller] Starting curl...")

        do {
            try process.run()
        } catch {
            throw InstallerError.downloadFailed(
                error.localizedDescription
            )
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let httpStatus = String(
            data: outputData,
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let curlError = String(
            data: errorData,
            encoding: .utf8
        ) ?? ""

        print("[WineRuntimeInstaller] HTTP status: \(httpStatus)")
        print("[WineRuntimeInstaller] Curl exit code: \(process.terminationStatus)")

        if !curlError.isEmpty {
            print("[WineRuntimeInstaller] Curl output: \(curlError)")
        }

        guard process.terminationStatus == 0,
              httpStatus == "200" else {

            throw InstallerError.downloadFailed(
                "curl failed. HTTP: \(httpStatus), exit code: \(process.terminationStatus)"
            )
        }

        guard fileManager.fileExists(atPath: archive.path) else {
            throw InstallerError.downloadFailed(
                "Downloaded archive does not exist"
            )
        }

        let attributes = try fileManager.attributesOfItem(
            atPath: archive.path
        )

        let fileSize = attributes[.size] as? Int64 ?? 0

        print("[WineRuntimeInstaller] Archive size: \(fileSize) bytes")

        guard fileSize > 0 else {
            throw InstallerError.downloadFailed(
                "Downloaded archive is empty"
            )
        }
    }


    private func verifyChecksum(release: WineRuntimeRelease) throws {

        print("[WineRuntimeInstaller] Verifying SHA256...")

        let actualHash = try calculateSHA256(
            for: archiveURL(for: release)
        )

        print("[WineRuntimeInstaller] Expected SHA256: \(release.sha256)")
        print("[WineRuntimeInstaller] Actual SHA256:   \(actualHash)")

        guard actualHash.lowercased() == release.sha256.lowercased() else {
            throw InstallerError.checksumMismatch
        }

        print("[WineRuntimeInstaller] SHA256 verification successful")
    }

    private func calculateSHA256(for url: URL) throws -> String {

        let fileHandle = try FileHandle(forReadingFrom: url)

        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()

        while true {

            let data = try fileHandle.read(upToCount: 1024 * 1024) ?? Data()

            if data.isEmpty {
                break
            }

            hasher.update(data: data)
        }

        let digest = hasher.finalize()

        return digest
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func extractRuntime(release: WineRuntimeRelease) throws {

        print("[WineRuntimeInstaller] Extracting Wine Runtime...")

        let fileManager = FileManager.default
        let staging = stagingDirectory(for: release)

        if fileManager.fileExists(atPath: staging.path) {
            try fileManager.removeItem(at: staging)
        }

        try fileManager.createDirectory(
            at: staging,
            withIntermediateDirectories: true
        )

        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")

        process.arguments = [
            "-xJf",
            archiveURL(for: release).path,
            "--strip-components", "1",
            "-C",
            staging.path
        ]

        let errorPipe = Pipe()

        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw InstallerError.extractionFailed(
                error.localizedDescription
            )
        }

        process.waitUntilExit()

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(
            data: errorData,
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0 else {

            throw InstallerError.extractionFailed(
                errorOutput.isEmpty
                    ? "tar exited with code \(process.terminationStatus)"
                    : errorOutput
            )
        }

        print("[WineRuntimeInstaller] Extraction completed")
    }

    private func validateRuntime(at directory: URL) throws {

        print("[WineRuntimeInstaller] Validating Runtime...")

        let fileManager = FileManager.default

        let wineURL = directory
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wine")

        let wineserverURL = directory
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wineserver")

        guard fileManager.fileExists(atPath: wineURL.path),
              fileManager.fileExists(atPath: wineserverURL.path) else {

            throw InstallerError.invalidRuntime
        }

        print("[WineRuntimeInstaller] wine: \(wineURL.path)")
        print("[WineRuntimeInstaller] wineserver: \(wineserverURL.path)")
    }

    private func setExecutablePermissions(release: WineRuntimeRelease) throws {

        print("[WineRuntimeInstaller] Setting executable permissions...")

        let staging = stagingDirectory(for: release)

        let wineURL = staging
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wine")

        let wineserverURL = staging
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wineserver")

        try runCommand(
            "/bin/chmod",
            arguments: ["755", wineURL.path]
        )

        try runCommand(
            "/bin/chmod",
            arguments: ["755", wineserverURL.path]
        )

        print("[WineRuntimeInstaller] Permissions updated")
    }

    private func diagnoseRuntime(release: WineRuntimeRelease) throws {

        let staging = stagingDirectory(for: release)

        let wineURL = staging
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wine")

        let wineserverURL = staging
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wineserver")

        print("[WineRuntimeInstaller] === Runtime diagnostics ===")

        diagnoseFile(at: wineURL)
        diagnoseFile(at: wineserverURL)

        try diagnoseExecution(at: wineURL)

        print("[WineRuntimeInstaller] === Diagnostics completed ===")
    }

    private func diagnoseFile(at url: URL) {

        let fileManager = FileManager.default

        let executable = fileManager.isExecutableFile(
            atPath: url.path
        )

        let accessResult = url.path.withCString {
            Darwin.access($0, X_OK)
        }

        let fileType = try? fileManager.attributesOfItem(
            atPath: url.path
        )[.type] as? FileAttributeType

        print("[WineRuntimeInstaller] File: \(url.lastPathComponent)")
        print("[WineRuntimeInstaller] Type: \(String(describing: fileType))")
        print("[WineRuntimeInstaller] Executable: \(executable)")
        print("[WineRuntimeInstaller] access(X_OK): \(accessResult)")
        print("[WineRuntimeInstaller] Quarantine: \(hasQuarantineAttribute(at: url))")
    }

    private func diagnoseExecution(at executableURL: URL) throws {

        print("[WineRuntimeInstaller] Testing Wine execution...")

        let process = Process()

        process.executableURL = executableURL
        process.arguments = ["--version"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw InstallerError.installationFailed(
                "Unable to launch Wine: \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(
            data: outputData,
            encoding: .utf8
        ) ?? ""

        let error = String(
            data: errorData,
            encoding: .utf8
        ) ?? ""

        print("[WineRuntimeInstaller] Wine output: \(output)")

        if !error.isEmpty {
            print("[WineRuntimeInstaller] Wine stderr: \(error)")
        }

        guard process.terminationStatus == 0 else {
            throw InstallerError.installationFailed(
                "Wine execution failed with exit code \(process.terminationStatus)"
            )
        }
    }
    
    private func installStagingRuntime(release: WineRuntimeRelease) throws {

        let fileManager = FileManager.default

        let staging = stagingDirectory(for: release)
        let destination = runtimeDirectory(for: release)
        
        guard !fileManager.fileExists(atPath: destination.path) else {

            throw InstallerError.existingRuntimeInvalid(
                destination.path
            )
        }

        do {
            try fileManager.moveItem(
                at: staging,
                to: destination
            )

            print(
                "[WineRuntimeInstaller] Runtime moved to: \(destination.path)"
            )

        } catch {

            throw InstallerError.installationFailed(
                error.localizedDescription
            )
        }
    }


    private func runCommand(_ executable: String, arguments: [String]) throws {

        let process = Process()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let errorPipe = Pipe()

        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw InstallerError.installationFailed(
                error.localizedDescription
            )
        }

        process.waitUntilExit()

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let errorOutput = String(
            data: errorData,
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0 else {

            throw InstallerError.installationFailed(
                errorOutput.isEmpty
                    ? "\(executable) exited with code \(process.terminationStatus)"
                    : errorOutput
            )
        }
    }


    private func isInstalled(release: WineRuntimeRelease) -> Bool {

        let fileManager = FileManager.default
        let directory = runtimeDirectory(for: release)

        let wineURL = wineExecutable(for: release)
        let wineserverURL = wineserverExecutable(for: release)

        guard fileManager.isExecutableFile(atPath: wineURL.path),
              fileManager.isExecutableFile(atPath: wineserverURL.path) else {
            return false
        }

        guard !hasQuarantineAttribute(at: directory) else {
            return false
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator {

            if hasQuarantineAttribute(at: fileURL) {
                return false
            }
        }

        return true
    }


    private func makeRuntime(release: WineRuntimeRelease    ) -> WineRuntime {
        WineRuntime(
            name: release.name,
            version: release.version,
            executableURL: wineExecutable(for: release)
        )
    }

    enum InstallerError: LocalizedError {
        case downloadFailed(String)
        case checksumMismatch
        case extractionFailed(String)
        case invalidRuntime
        case installationFailed(String)
        case permissionFixFailed(String)
        case quarantineDetected
        case existingRuntimeInvalid(String)

        var errorDescription: String? {

            switch self {
            case .downloadFailed(let message):
                return "Wine Runtime download failed: \(message)"
            case .checksumMismatch:
                return "Wine Runtime SHA-256 checksum mismatch."
            case .extractionFailed(let message):
                return "Wine Runtime extraction failed: \(message)"
            case .invalidRuntime:
                return "Downloaded Wine Runtime is invalid or incomplete."
            case .installationFailed(let message):
                return "Wine Runtime installation failed: \(message)"
            case .permissionFixFailed(let message):
                return "Unable to fix Wine Runtime permissions: \(message)"
            case .quarantineDetected:
                return "macOS quarantine was detected in Wine Runtime files."
            case .existingRuntimeInvalid(let path):
                return """
                A Runtime directory already exists but is invalid:
                \(path)

                Remove or repair it manually before installing this release.
                """
            }
        }
    }
}
