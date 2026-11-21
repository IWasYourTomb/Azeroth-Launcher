//
//  WineRuntimeValidator.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation

struct WineRuntimeValidationResult {
    let isValid: Bool
    let version: String?
    let architecture: String?
    let error: String?

    static func success(version: String, architecture: String)-> Self {
        WineRuntimeValidationResult(
            isValid: true,
            version: version,
            architecture: architecture,
            error: nil
        )
    }

    static func failure(_ error: String) -> Self {
        WineRuntimeValidationResult(
            isValid: false,
            version: nil,
            architecture: nil,
            error: error
        )
    }
}

actor WineRuntimeValidator {
    private let fileManager = FileManager.default

    private let lipoURL = URL(
        fileURLWithPath: "/usr/bin/lipo"
    )

    private let archURL = URL(
        fileURLWithPath: "/usr/bin/arch"
    )

    func validate(at runtimeDirectory: URL) async -> WineRuntimeValidationResult {

        let runtimeDirectory = runtimeDirectory.standardizedFileURL

        print("[WineRuntimeValidator] Validating Runtime")
        print("[WineRuntimeValidator] Path: \(runtimeDirectory.path)")

        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: runtimeDirectory.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return .failure(
                "Runtime directory does not exist."
            )
        }

        let binDirectory = runtimeDirectory
            .appendingPathComponent("bin", isDirectory: true)

        let wineExecutable = binDirectory
            .appendingPathComponent("wine")

        let wineserverExecutable = binDirectory
            .appendingPathComponent("wineserver")

        guard fileManager.isExecutableFile(
            atPath: wineExecutable.path
        ) else {
            return .failure(
                "Wine executable is missing or not executable."
            )
        }
        guard fileManager.isExecutableFile(
            atPath: wineserverExecutable.path
        ) else {

            return .failure(
                "Wineserver executable is missing or not executable."
            )
        }

        do {
            let wineArchitectures = try executableArchitectures(
                at: wineExecutable
            )

            let wineserverArchitectures = try executableArchitectures(
                at: wineserverExecutable
            )

            let commonArchitectures = wineArchitectures
                .intersection(wineserverArchitectures)

            guard !commonArchitectures.isEmpty else {
                return .failure(
                    "Wine and Wineserver architectures do not match."
                )
            }

            print(
                "[WineRuntimeValidator] Wine architectures: \(wineArchitectures)"
            )

            print(
                "[WineRuntimeValidator] Wineserver architectures: \(wineserverArchitectures)"
            )

            let preferredArchitectures = [
                "arm64",
                "x86_64"
            ]

            guard let selectedArchitecture = preferredArchitectures.first(
                where: { commonArchitectures.contains($0) }
            ) else {

                return .failure(
                    "Runtime architecture is not supported. Found: \(commonArchitectures)"
                )
            }
            
            let version = try executeWineVersion(
                executable: wineExecutable,
                architecture: selectedArchitecture
            )

            guard !version.isEmpty else {

                return .failure(
                    "Wine returned an empty version."
                )
            }

            print(
                "[WineRuntimeValidator] Valid Runtime: \(version)"
            )

            print(
                "[WineRuntimeValidator] Architecture: \(selectedArchitecture)"
            )

            return .success(
                version: version,
                architecture: selectedArchitecture
            )

        } catch {
            print(
                "[WineRuntimeValidator] Validation failed: \(error.localizedDescription)"
            )

            return .failure(
                error.localizedDescription
            )
        }
    }

    private func executableArchitectures(at executable: URL) throws -> Set<String> {
        let output = try executeCommand(
            executable: lipoURL,
            arguments: [
                "-archs",
                executable.path
            ]
        )

        let supportedArchitectures: Set<String> = [
            "arm64",
            "x86_64"
        ]

        let architectures = Set(
            output
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .filter {
                    supportedArchitectures.contains($0)
                }
        )

        guard !architectures.isEmpty else {

            throw ValidatorError.unsupportedArchitecture(
                executable.lastPathComponent
            )
        }

        return architectures
    }

    private func executeWineVersion(executable: URL, architecture: String) throws -> String {
        let output = try executeCommand(
            executable: archURL,
            arguments: [
                "-\(architecture)",
                executable.path,
                "--version"
            ]
        )

        let version = output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !version.isEmpty else {
            throw ValidatorError.emptyVersion
        }

        return version
    }

    private func executeCommand(executable: URL, arguments: [String]) throws -> String {
        let process = Process()

        process.executableURL = executable
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {

            throw ValidatorError.executionFailed(
                error.localizedDescription
            )
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(
            data: outputData,
            encoding: .utf8
        ) ?? ""

        let errorOutput = String(
            data: errorData,
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0 else {

            throw ValidatorError.executionFailed(
                errorOutput.isEmpty
                    ? output
                    : errorOutput
            )
        }

        return output
    }

    enum ValidatorError: LocalizedError {
        case unsupportedArchitecture(String)
        case executionFailed(String)
        case emptyVersion
        var errorDescription: String? {

            switch self {

            case .unsupportedArchitecture(let executable):
                return """
                Unsupported architecture in executable:
                \(executable)
                """

            case .executionFailed(let message):
                return message.isEmpty
                    ? "Failed to execute Wine Runtime."
                    : "Wine Runtime execution failed: \(message)"

            case .emptyVersion: return "Wine returned an empty version."
            }
        }
    }
}
