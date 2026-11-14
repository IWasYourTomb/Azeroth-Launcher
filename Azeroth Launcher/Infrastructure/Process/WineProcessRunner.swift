//
//  WineProcessRunner.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation

enum WineProcessRunner {
    struct Result {
        let terminationStatus: Int32
    }

    enum RunnerError: LocalizedError {
        case executableNotFound(URL)
        case launchFailed(Error)
        case nonZeroExit(Int32)

        var errorDescription: String? {
            switch self {
            case .executableNotFound(let url):
                return "Executable not found: \(url.path)"

            case .launchFailed(let error):
                return "Failed to launch process: \(error.localizedDescription)"

            case .nonZeroExit(let status):
                return "Process terminated with exit code: \(status)"
            }
        }
    }


    @discardableResult
    static func run(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil
    ) throws -> Result {

        let process = try makeProcess(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )

        do {
            try process.run()
        } catch {
            throw RunnerError.launchFailed(error)
        }

        process.waitUntilExit()

        return Result(
            terminationStatus: process.terminationStatus
        )
    }

    @discardableResult
    static func runAndValidate(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil
    ) throws -> Result {

        let result = try run(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )

        guard result.terminationStatus == 0 else {
            throw RunnerError.nonZeroExit(
                result.terminationStatus
            )
        }

        return result
    }

    @discardableResult
    static func launch(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryURL: URL? = nil
    ) throws -> Process {

        let process = try makeProcess(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL
        )

        do {
            try process.run()
        } catch {
            throw RunnerError.launchFailed(error)
        }

        return process
    }

    private static func makeProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL?
    ) throws -> Process {

        guard FileManager.default.isExecutableFile(
            atPath: executableURL.path
        ) else {
            throw RunnerError.executableNotFound(
                executableURL
            )
        }

        let process = Process()

        process.executableURL = executableURL
        process.arguments = arguments

        var processEnvironment = ProcessInfo.processInfo.environment

        for (key, value) in environment {
            processEnvironment[key] = value
        }

        process.environment = processEnvironment

        if let currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }

        let logsDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("AzerothLauncher/Logs", isDirectory: true)

        try FileManager.default.createDirectory(
            at: logsDirectory,
            withIntermediateDirectories: true
        )

        let logURL = logsDirectory
            .appendingPathComponent("wine-launch.log")

        FileManager.default.createFile(
            atPath: logURL.path,
            contents: nil
        )

        let logHandle = try FileHandle(forWritingTo: logURL)
        try logHandle.seekToEnd()

        process.standardOutput = logHandle
        process.standardError = logHandle

        return process
    }
}
