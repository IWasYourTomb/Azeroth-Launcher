//
//  WineHomeManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation

struct WineHomeManager {

    // MARK: - Properties

    private let fileManager: FileManager
    private let rootDirectory: URL

    var homeDirectory: URL {
        rootDirectory.appendingPathComponent(
            "Home",
            isDirectory: true
        )
    }

    var wineDirectory: URL {
        homeDirectory.appendingPathComponent(
            "Wine",
            isDirectory: true
        )
    }

    // MARK: - Initialization

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager

        self.rootDirectory = rootDirectory
            ?? fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent(
                "AzerothLauncher",
                isDirectory: true
            )
    }

    // MARK: - Public Methods

    func prepare() throws {
        try fileManager.createDirectory(
            at: wineDirectory,
            withIntermediateDirectories: true
        )
    }

    func configureProfile(
        in prefixDirectory: URL,
        replaceGeneratedProfile: Bool = false
    ) throws {

        try prepare()

        let username = currentUsername()

        guard isValidPathComponent(username) else {
            throw WineHomeError.invalidUsername(username)
        }

        let usersDirectory = prefixDirectory
            .appendingPathComponent("drive_c", isDirectory: true)
            .appendingPathComponent("users", isDirectory: true)

        try fileManager.createDirectory(
            at: usersDirectory,
            withIntermediateDirectories: true
        )

        let profileDirectory = usersDirectory
            .appendingPathComponent(username, isDirectory: true)

        let relativeTarget = relativePath(
            from: usersDirectory,
            to: wineDirectory
        )

        // Проверяем существующую символическую ссылку.
        if let existingTarget = try? fileManager.destinationOfSymbolicLink(
            atPath: profileDirectory.path
        ) {

            if existingTarget == relativeTarget {
                return
            }

            try fileManager.removeItem(at: profileDirectory)
        }

        // Если это обычная директория, не удаляем её без разрешения.
        else if fileManager.fileExists(
            atPath: profileDirectory.path
        ) {

            guard replaceGeneratedProfile else {
                return
            }

            try fileManager.removeItem(at: profileDirectory)
        }

        try fileManager.createSymbolicLink(
            atPath: profileDirectory.path,
            withDestinationPath: relativeTarget
        )
    }

    // MARK: - Private Methods

    private func currentUsername() -> String {
        let environmentUsername = ProcessInfo.processInfo.environment["USER"]

        if let environmentUsername,
           !environmentUsername.isEmpty {
            return environmentUsername
        }

        return NSUserName()
    }

    private func isValidPathComponent(_ value: String) -> Bool {
        !value.isEmpty
        && value != "."
        && value != ".."
        && !value.contains("/")
    }

    private func relativePath(
        from source: URL,
        to destination: URL
    ) -> String {

        let sourceComponents = source.standardizedFileURL.pathComponents
        let destinationComponents = destination.standardizedFileURL.pathComponents

        var commonIndex = 0

        while commonIndex < min(
            sourceComponents.count,
            destinationComponents.count
        ) {
            guard sourceComponents[commonIndex]
                == destinationComponents[commonIndex] else {
                break
            }

            commonIndex += 1
        }

        let upwardComponents = Array(
            repeating: "..",
            count: sourceComponents.count - commonIndex
        )

        let downwardComponents = destinationComponents.dropFirst(
            commonIndex
        )

        return (
            upwardComponents + Array(downwardComponents)
        ).joined(separator: "/")
    }
}

enum WineHomeError: LocalizedError {

    case invalidUsername(String)

    var errorDescription: String? {
        switch self {
        case .invalidUsername(let username):
            return "Invalid macOS username: \(username)"
        }
    }
}
