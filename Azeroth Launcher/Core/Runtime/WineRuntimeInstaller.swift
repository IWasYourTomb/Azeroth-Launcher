//
//  WineRuntimeInstaller.swift
//  Azeroth Launcher
//

import Foundation
import CryptoKit
import Darwin

actor WineRuntimeInstaller {
    private let runtimeName = "WineAndAqua"
    private let runtimeVersion = "11.13 (r17)"
    private let runtimeDirectoryName = "Wine-r17"

    private let downloadURL = URL(
        string: "https://github.com/WoWSilicon/WoWSilicon/releases/download/wine-runtime-r17/WoWSilicon-WineRuntime-r17.tar.xz"
    )!

    private let expectedSHA256 =
        "dc67cf0c2dd1e4c1cfaffe924f4737aaa594645b135a7973ac3505c83c70f882"

    private let quarantineAttribute = "com.apple.quarantine"

    private var applicationSupportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AzerothLauncher", isDirectory: true)
    }

    private var runtimeDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("Runtimes", isDirectory: true)
            .appendingPathComponent(runtimeDirectoryName, isDirectory: true)
    }

    private var downloadsDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    private var archiveURL: URL {
        downloadsDirectory
            .appendingPathComponent("wine-runtime-r17.tar.xz")
    }

    private var stagingDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("Runtimes", isDirectory: true)
            .appendingPathComponent(".Wine-r17-staging", isDirectory: true)
    }

    private var backupDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("Runtimes", isDirectory: true)
            .appendingPathComponent(".Wine-r17-backup", isDirectory: true)
    }

    private var wineExecutable: URL {
        runtimeDirectory
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wine")
    }

    private var wineserverExecutable: URL {
        runtimeDirectory
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("wineserver")
    }

    func install() async throws -> WineRuntime {

        print("[WineRuntimeInstaller] Starting installation")

        if isInstalled {
            print("[WineRuntimeInstaller] Runtime already installed")
            return makeRuntime()
        }

        do {
            try createDirectories()

            try diagnoseQuarantineExclusion()

            try downloadRuntime()

            try verifyChecksum()

            print("[WineRuntimeInstaller] Checking archive quarantine...")

            if hasQuarantineAttribute(at: archiveURL) {
                print("[WineRuntimeInstaller] WARNING: Archive contains quarantine attribute")
            } else {
                print("[WineRuntimeInstaller] Archive has no quarantine attribute")
            }

            try extractRuntime()

            try validateRuntime()

            try diagnoseExtractedQuarantine()

            try setExecutablePermissions()

            try diagnoseRuntime()

            try installStagingRuntime()

            print("[WineRuntimeInstaller] Installation completed successfully")

            return makeRuntime()

        } catch {
            print("[WineRuntimeInstaller] Installation failed: \(error.localizedDescription)")
            throw error
        }
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
            at: runtimeDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        print("[WineRuntimeInstaller] Application directory: \(applicationSupportDirectory.path)")
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

    private func diagnoseExtractedQuarantine() throws {

        print("[WineRuntimeInstaller] === Extracted quarantine diagnostics ===")

        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: stagingDirectory,
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

                print("[WineRuntimeInstaller] QUARANTINE FOUND: \(fileURL.path)")
            }
        }

        print("[WineRuntimeInstaller] Checked files: \(checkedFiles)")
        print("[WineRuntimeInstaller] Quarantined files: \(quarantinedFiles)")
    }

    private func downloadRuntime() throws {

        print("[WineRuntimeInstaller] Downloading Wine Runtime using curl...")
        print("[WineRuntimeInstaller] Archive path: \(archiveURL.path)")

        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
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
            "--output", archiveURL.path,
            "--write-out", "%{http_code}",
            downloadURL.absoluteString
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("[WineRuntimeInstaller] Starting curl...")

        do {
            try process.run()
        } catch {
            throw InstallerError.downloadFailed(error.localizedDescription)
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

        guard fileManager.fileExists(atPath: archiveURL.path) else {
            throw InstallerError.downloadFailed("Downloaded archive does not exist")
        }

        let attributes = try fileManager.attributesOfItem(atPath: archiveURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        print("[WineRuntimeInstaller] Archive size: \(fileSize) bytes")

        guard fileSize > 0 else {
            throw InstallerError.downloadFailed("Downloaded archive is empty")
        }
    }

    private func verifyChecksum() throws {

        print("[WineRuntimeInstaller] Verifying SHA256...")

        let actualHash = try calculateSHA256(for: archiveURL)

        print("[WineRuntimeInstaller] Expected SHA256: \(expectedSHA256)")
        print("[WineRuntimeInstaller] Actual SHA256:   \(actualHash)")

        guard actualHash.lowercased() == expectedSHA256.lowercased() else {
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

    private func hasQuarantineAttribute(at url: URL) -> Bool {

        let result = url.path.withCString { path in
            quarantineAttribute.withCString { attributeName in
                Darwin.getxattr(path, attributeName, nil, 0, 0, 0)
            }
        }

        return result >= 0
    }


    private func extractRuntime() throws {

        print("[WineRuntimeInstaller] Extracting Wine Runtime...")

        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: stagingDirectory.path) {
            try fileManager.removeItem(at: stagingDirectory)
        }

        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )

        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")

        process.arguments = [
            "-xJf",
            archiveURL.path,
            "--strip-components", "1",
            "-C",
            stagingDirectory.path
        ]

        let errorPipe = Pipe()

        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw InstallerError.extractionFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw InstallerError.extractionFailed(
                errorOutput.isEmpty
                    ? "tar exited with code \(process.terminationStatus)"
                    : errorOutput
            )
        }

        print("[WineRuntimeInstaller] Extraction completed")
    }


    private func validateRuntime() throws {

        print("[WineRuntimeInstaller] Validating Runtime...")

        let fileManager = FileManager.default

        let wineURL = stagingDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("wine")

        let wineserverURL = stagingDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("wineserver")

        guard fileManager.fileExists(atPath: wineURL.path),
              fileManager.fileExists(atPath: wineserverURL.path) else {
            throw InstallerError.invalidRuntime
        }

        print("[WineRuntimeInstaller] wine: \(wineURL.path)")
        print("[WineRuntimeInstaller] wineserver: \(wineserverURL.path)")
    }

    private func setExecutablePermissions() throws {

        print("[WineRuntimeInstaller] Setting executable permissions...")

        let wineURL = stagingDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("wine")

        let wineserverURL = stagingDirectory
            .appendingPathComponent("bin")
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

    private func diagnoseRuntime() throws {

        let wineURL = stagingDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("wine")

        let wineserverURL = stagingDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("wineserver")

        print("[WineRuntimeInstaller] === Runtime diagnostics ===")

        diagnoseFile(at: wineURL)
        diagnoseFile(at: wineserverURL)

        try diagnoseExecution(at: wineURL)

        print("[WineRuntimeInstaller] === Diagnostics completed ===")
    }

    private func diagnoseFile(at url: URL) {

        let fileManager = FileManager.default

        let executable = fileManager.isExecutableFile(atPath: url.path)

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

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

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

    private func installStagingRuntime() throws {

        let fileManager = FileManager.default

        var movedExistingRuntime = false

        if fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.removeItem(at: backupDirectory)
        }

        if fileManager.fileExists(atPath: runtimeDirectory.path) {

            print("[WineRuntimeInstaller] Backing up existing Runtime...")

            try fileManager.moveItem(
                at: runtimeDirectory,
                to: backupDirectory
            )

            movedExistingRuntime = true
        }

        do {

            try fileManager.moveItem(
                at: stagingDirectory,
                to: runtimeDirectory
            )

            print("[WineRuntimeInstaller] Runtime moved to final directory")

            if movedExistingRuntime,
               fileManager.fileExists(atPath: backupDirectory.path) {

                try? fileManager.removeItem(at: backupDirectory)
            }

        } catch {

            print("[WineRuntimeInstaller] Failed to move staging Runtime")

            if movedExistingRuntime,
               fileManager.fileExists(atPath: backupDirectory.path) {

                try? fileManager.moveItem(
                    at: backupDirectory,
                    to: runtimeDirectory
                )
            }

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
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw InstallerError.installationFailed(
                errorOutput.isEmpty
                    ? "\(executable) exited with code \(process.terminationStatus)"
                    : errorOutput
            )
        }
    }

    private var isInstalled: Bool {

        let fileManager = FileManager.default

        guard fileManager.isExecutableFile(atPath: wineExecutable.path),
              fileManager.isExecutableFile(atPath: wineserverExecutable.path) else {
            return false
        }

        guard !hasQuarantineAttribute(at: runtimeDirectory) else {
            return false
        }

        guard let enumerator = fileManager.enumerator(
            at: runtimeDirectory,
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

    private func makeRuntime() -> WineRuntime {

        WineRuntime(
            name: runtimeName,
            version: runtimeVersion,
            executableURL: wineExecutable
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
            }
        }
    }
}
