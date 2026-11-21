//
//  WineSessionMonitor.swift
//  Azeroth Launcher
//
//  Created by Матвей on 15.11.2026.
//

import Foundation

final class WineSessionMonitor {

    private let process: Process

    private init(process: Process) {
        self.process = process
    }

    var isRunning: Bool {
        process.isRunning
    }

    var terminationStatus: Int32? {
        guard !process.isRunning else {
            return nil
        }

        return process.terminationStatus
    }

    func terminate() {
        guard process.isRunning else {
            return
        }

        process.terminate()
    }

    static func start(wineserverURL: URL, prefixURL: URL, homeDirectory: URL) throws -> WineSessionMonitor {

        let process = Process()

        process.executableURL = wineserverURL
        process.arguments = ["-w"]
        process.environment = makeEnvironment(
            prefixURL: prefixURL,
            homeDirectory: homeDirectory
        )

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()

        print("[WineSessionMonitor] Started")
        print("[WineSessionMonitor] PID: \(process.processIdentifier)")
        print("[WineSessionMonitor] Prefix: \(prefixURL.path)")

        return WineSessionMonitor(process: process)
    }

    static func attachIfRunning(
        wineserverURL: URL,
        prefixURL: URL,
        homeDirectory: URL,
        timeout: TimeInterval = 0.25
    ) async throws -> WineSessionMonitor? {

        let monitor = try start(
            wineserverURL: wineserverURL,
            prefixURL: prefixURL,
            homeDirectory: homeDirectory
        )

        let deadline = Date().addingTimeInterval(timeout)

        while monitor.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        guard monitor.isRunning else {
            print("[WineSessionMonitor] No active server: \(prefixURL.path)")
            return nil
        }

        print("[WineSessionMonitor] Attached: \(prefixURL.path)")
        return monitor
    }

    private static func makeEnvironment(prefixURL: URL, homeDirectory: URL) -> [String: String] {

        var environment = ProcessInfo.processInfo.environment

        environment["HOME"] = homeDirectory.path
        environment["WINEPREFIX"] = prefixURL.path

        return environment
    }
}
