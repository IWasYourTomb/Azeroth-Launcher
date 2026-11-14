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
    let error: String?

    static func success(version: String) -> Self {
        WineRuntimeValidationResult(
            isValid: true,
            version: version,
            error: nil
        )
    }

    static func failure(_ error: String) -> Self {
        WineRuntimeValidationResult(
            isValid: false,
            version: nil,
            error: error
        )
    }
}

actor WineRuntimeValidator {

    func validate(at runtimeDirectory: URL) async -> WineRuntimeValidationResult {
        let fileManager = FileManager.default

        let binDirectory = runtimeDirectory
            .appendingPathComponent("bin", isDirectory: true)

        let wineExecutable = binDirectory
            .appendingPathComponent("wine", isDirectory: false)

        let wineserverExecutable = binDirectory
            .appendingPathComponent("wineserver", isDirectory: false)

        print("[WineRuntimeValidator] Runtime: \(runtimeDirectory.path)")
        print("[WineRuntimeValidator] Bin: \(binDirectory.path)")
        
        print("[WineRuntimeValidator] Wine path: \(wineExecutable.path)")
        print("[WineRuntimeValidator] Wine exists: \(fileManager.fileExists(atPath: wineExecutable.path))")
        print("[WineRuntimeValidator] Wine executable: \(fileManager.isExecutableFile(atPath: wineExecutable.path))")

        if let attributes = try? fileManager.attributesOfItem(
            atPath: wineExecutable.path
        ) {
            print("[WineRuntimeValidator] Wine permissions: \(attributes[.posixPermissions] ?? "unknown")")
            print("[WineRuntimeValidator] Wine file type: \(attributes[.type] ?? "unknown")")
        }
        print("[WineRuntimeValidator] Wineserver path: \(wineserverExecutable.path)")
        print("[WineRuntimeValidator] Wineserver exists: \(fileManager.fileExists(atPath: wineserverExecutable.path))")
        print("[WineRuntimeValidator] Wineserver executable: \(fileManager.isExecutableFile(atPath: wineserverExecutable.path))")

        if let attributes = try? fileManager.attributesOfItem(
            atPath: wineserverExecutable.path
        ) {
            print("[WineRuntimeValidator] Wineserver permissions: \(attributes[.posixPermissions] ?? "unknown")")
            print("[WineRuntimeValidator] Wineserver file type: \(attributes[.type] ?? "unknown")")
        }
        guard fileManager.fileExists(atPath: wineExecutable.path) else {
            return .failure(
                "Wine executable does not exist: \(wineExecutable.path)"
            )
        }

        guard fileManager.fileExists(atPath: wineserverExecutable.path) else {
            return .failure(
                "Wineserver executable does not exist: \(wineserverExecutable.path)"
            )
        }
        do {
            print("[WineRuntimeValidator] Executing wine --version")

            let output = try await executeWineVersion(
                executable: wineExecutable
            )

            let version = output.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !version.isEmpty else {
                return .failure("Wine returned an empty version.")
            }

            print("[WineRuntimeValidator] Valid runtime: \(version)")

            return .success(version: version)

        } catch {
            print("[WineRuntimeValidator] Execution failed: \(error.localizedDescription)")

            return .failure(error.localizedDescription)
        }
    }


    private func executeWineVersion(executable: URL) async throws -> String {
        let process = Process()

        let archExecutable = URL(fileURLWithPath: "/usr/bin/arch")

        process.executableURL = archExecutable
        process.arguments = [
            "-x86_64",
            executable.path,
            "--version"
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                print("[WineRuntimeValidator] Exit code: \(process.terminationStatus)")
                print("[WineRuntimeValidator] Output: \(output)")

                guard process.terminationStatus == 0 else {
                    continuation.resume(
                        throwing: ValidatorError.executionFailed(
                            output.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                    return
                }

                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                let nsError = error as NSError

                print("[WineRuntimeValidator] Launch error domain: \(nsError.domain)")
                print("[WineRuntimeValidator] Launch error code: \(nsError.code)")
                print("[WineRuntimeValidator] Launch error: \(nsError.localizedDescription)")

                continuation.resume(throwing: error)
            }
        }
    }

    enum ValidatorError: LocalizedError {
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .executionFailed(let output):
                if output.isEmpty {
                    return "Wine failed to execute."
                }

                return "Wine execution failed: \(output)"
            }
        }
    }
}
