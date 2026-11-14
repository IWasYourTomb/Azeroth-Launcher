//
//  WineRuntimeDetector.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation

actor WineRuntimeDetector {

    private let fileManager = FileManager.default
    private let validator: WineRuntimeValidator

    init(
        validator: WineRuntimeValidator = WineRuntimeValidator()
    ) {
        self.validator = validator
    }

    private var runtimesDirectory: URL {
        fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent(
            "AzerothLauncher/Runtimes",
            isDirectory: true
        )
    }

    func detect() async -> [WineRuntime] {

        print("[WineRuntimeDetector] Searching in: \(runtimesDirectory.path)")

        guard fileManager.fileExists(
            atPath: runtimesDirectory.path
        ) else {
            print("[WineRuntimeDetector] Runtimes directory does not exist.")
            return []
        }

        do {
            let directories = try fileManager.contentsOfDirectory(
                at: runtimesDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var detectedRuntimes: [WineRuntime] = []

            for directory in directories {

                let resourceValues = try? directory.resourceValues(
                    forKeys: [.isDirectoryKey]
                )

                guard resourceValues?.isDirectory == true else {
                    continue
                }

                print("[WineRuntimeDetector] Checking: \(directory.path)")

                let result = await validator.validate(at: directory)

                guard result.isValid else {
                    print(
                        """
                        [WineRuntimeDetector] Invalid runtime: \(directory.lastPathComponent)
                        Reason: \(result.error ?? "Unknown validation error")
                        """
                    )
                    continue
                }

                let runtime = WineRuntime(
                    name: directory.lastPathComponent,
                    version: result.version ?? "Unknown",
                    executableURL: directory
                        .appendingPathComponent("bin", isDirectory: true)
                        .appendingPathComponent("wine")
                )

                detectedRuntimes.append(runtime)

                print("[WineRuntimeDetector] Found: \(runtime.displayName)")
            }

            return detectedRuntimes

        } catch {
            print("[WineRuntimeDetector] Detection failed: \(error.localizedDescription)")
            return []
        }
    }
}
