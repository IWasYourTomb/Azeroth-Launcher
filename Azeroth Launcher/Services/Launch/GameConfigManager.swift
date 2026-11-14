//
//  GameConfigManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation

import AppKit

@MainActor

final class GameConfigManager {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {

        self.fileManager = fileManager

    }

    private struct DisplayResolution {
        let width: Int
        let height: Int
        var description: String {
            "\(width)x\(height)"
        }
    }

    private func currentDisplayResolution() throws -> DisplayResolution {
        let screen = NSApplication.shared.keyWindow?.screen
            ?? NSScreen.main

        guard let screen else {
            throw GameConfigError.displayUnavailable
        }

        let width = Int(screen.frame.width.rounded())

        let height = Int(screen.frame.height.rounded())

        guard width > 0, height > 0 else {

            throw GameConfigError.invalidResolution

        }

        return DisplayResolution(
            width: width,
            height: height
        )
    }

    func prepare(for installation: GameInstallation) throws {
        let resolution = try currentDisplayResolution()
        let wowDirectory = installation.installationPath
        let wtfDirectory = wowDirectory
            .appendingPathComponent("WTF", isDirectory: true)

        let configURL = wtfDirectory
            .appendingPathComponent("Config.wtf")

        try fileManager.createDirectory(
            at: wtfDirectory,
            withIntermediateDirectories: true
        )

        let originalContent: String
        if fileManager.fileExists(atPath: configURL.path) {
            originalContent = try String(
                contentsOf: configURL,
                encoding: .utf8
            )
        } else {
            originalContent = ""
        }

        let updatedContent = updateConfiguration(
            originalContent,
            resolution: resolution
        )

        guard updatedContent != originalContent else {
            print("[GameConfigManager] Config.wtf already configured")
            return
        }

        try Data(updatedContent.utf8).write(
            to: configURL,
            options: .atomic
        )

        print("[GameConfigManager] Config.wtf updated")
        print("[GameConfigManager] Resolution: \(resolution.description)")
        print("[GameConfigManager] Windowed mode: enabled")
        print("[GameConfigManager] Maximized: enabled")
    }

    private func updateConfiguration( _ content: String,resolution: DisplayResolution) -> String {
        let values: [String: String] = [
            "gxResolution": resolution.description,
            "gxWindow": "1",
            "gxMaximize": "1"
        ]

        let lineEnding = content.contains("\r\n")
            ? "\r\n"
            : "\n"

        var lines = content.isEmpty
            ? []
            : content.components(separatedBy: lineEnding)

        var processedKeys = Set<String>()
        var updatedLines: [String] = []
        for line in lines {
            guard let key = configurationKey(in: line),
                  let value = values[key] else {
                updatedLines.append(line)
                continue
            }
            
            if processedKeys.insert(key).inserted {
                updatedLines.append("SET \(key) \"\(value)\"")
            }
        }

        for key in [
            "gxResolution",
            "gxWindow",
            "gxMaximize"
        ] where !processedKeys.contains(key) {
            updatedLines.append("SET \(key) \"\(values[key]!)\"")

        }

        return updatedLines.joined(separator: lineEnding)

    }

    private func configurationKey(in line: String) -> String? {
        let components = line
            .trimmingCharacters(in: .whitespaces)
            .split(
                maxSplits: 2,
                omittingEmptySubsequences: true,
                whereSeparator: { $0.isWhitespace }
            )

        guard components.count >= 2,
              components[0].uppercased() == "SET" else {
            return nil
        }

        let key = String(components[1])

        guard [
            "gxResolution",
            "gxWindow",
            "gxMaximize"
        ].contains(key) else {
            return nil
        }
        return key
    }
}

enum GameConfigError: LocalizedError {
    case displayUnavailable
    case invalidResolution
    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            return "Unable to detect the current display."
        case .invalidResolution:
            return "Invalid display resolution."
        }
    }
}
