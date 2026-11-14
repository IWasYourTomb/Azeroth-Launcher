import Foundation

actor PrefixManager {
    private let fileManager: FileManager
    private let homeManager: WineHomeManager
    private let baseDirectory: URL
    
    init(
        fileManager: FileManager = .default,
        homeManager: WineHomeManager = WineHomeManager()
    ) {
        self.fileManager = fileManager
        self.homeManager = homeManager
        
        self.baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent(
                "AzerothLauncher/Prefixes",
                isDirectory: true
            )
    }
    
    func prefixURL(for edition: GameEdition) -> URL {
        baseDirectory.appendingPathComponent(
            edition.rawValue,
            isDirectory: true
        )
    }
    
    func exists(for edition: GameEdition) -> Bool {
        fileManager.fileExists(
            atPath: prefixURL(for: edition).path
        )
    }
    
    
    func create(for edition: GameEdition, runtime: WineRuntime) async throws -> URL {
        
        let destination = prefixURL(for: edition)
        
        guard !fileManager.fileExists(
            atPath: destination.path
        ) else {
            throw PrefixError.alreadyExists(destination)
        }
        
        guard runtime.isAvailable else {
            throw PrefixError.runtimeUnavailable(
                runtime.executableURL
            )
        }
        
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        
        let stagingDirectory = baseDirectory
            .appendingPathComponent(
                ".staging-\(UUID().uuidString)",
                isDirectory: true
            )
        
        do {
            try fileManager.createDirectory(
                at: stagingDirectory,
                withIntermediateDirectories: true
            )
            
            try initialize(
                prefix: stagingDirectory,
                runtime: runtime
            )
            
            try validateStructure(prefix: stagingDirectory)
            
            try homeManager.configureProfile(
                in: stagingDirectory,
                replaceGeneratedProfile: true
            )
            
            try validateStructure(prefix: stagingDirectory)
            
            try fileManager.moveItem(
                at: stagingDirectory,
                to: destination
            )
            
            return destination
            
        } catch {
            try? fileManager.removeItem(
                at: stagingDirectory
            )
            
            throw error
        }
    }
    
    func remove(for edition: GameEdition) throws {
        let url = prefixURL(for: edition)
        
        guard fileManager.fileExists(
            atPath: url.path
        ) else {
            return
        }
        
        try fileManager.removeItem(at: url)
    }
    
    
    func validate(for edition: GameEdition) -> PrefixValidationResult {
        validate(at: prefixURL(for: edition))
    }

    func validate(at prefix: URL) -> PrefixValidationResult {

        var issues: [String] = []

        guard fileManager.fileExists(
            atPath: prefix.path
        ) else {
            return PrefixValidationResult(
                prefixURL: prefix,
                issues: ["Prefix does not exist"]
            )
        }

        let requiredFiles = [
            "system.reg",
            "user.reg",
            "userdef.reg"
        ]

        for file in requiredFiles {
            let fileURL = prefix.appendingPathComponent(file)

            if !fileManager.fileExists(
                atPath: fileURL.path
            ) {
                issues.append("Missing file: \(file)")
            }
        }

        let driveC = prefix.appendingPathComponent(
            "drive_c",
            isDirectory: true
        )

        if !fileManager.fileManagerDirectoryExists(at: driveC) {
            issues.append("Missing drive_c directory")
        }

        let usersDirectory = driveC.appendingPathComponent(
            "users",
            isDirectory: true
        )

        if !fileManager.fileManagerDirectoryExists(at: usersDirectory) {
            issues.append("Missing drive_c/users directory")
        }

        let wineHome = homeManager.wineDirectory

        if !fileManager.fileManagerDirectoryExists(at: wineHome) {
            issues.append("Wine Home directory does not exist")
        }

        if fileManager.fileManagerDirectoryExists(at: usersDirectory),
           fileManager.fileManagerDirectoryExists(at: wineHome) {

            do {
                let userDirectories = try fileManager.contentsOfDirectory(
                    at: usersDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                let expectedHome = wineHome
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                    .path

                let profileConfigured = userDirectories.contains { userDirectory in

                    do {
                        let destination = try fileManager.destinationOfSymbolicLink(
                            atPath: userDirectory.path
                        )

                        let resolvedDestination = URL(
                            fileURLWithPath: destination,
                            relativeTo: userDirectory.deletingLastPathComponent()
                        )
                        .standardizedFileURL
                        .resolvingSymlinksInPath()

                        return resolvedDestination.path == expectedHome

                    } catch {
                        return false
                    }
                }

                if !profileConfigured {
                    issues.append(
                        "Shared Wine user profile is not configured"
                    )
                }

            } catch {
                issues.append(
                    "Unable to inspect Wine user profiles: \(error.localizedDescription)"
                )
            }
        }

        return PrefixValidationResult(
            prefixURL: prefix,
            issues: issues
        )
    }
    
    
    private func initialize(prefix: URL, runtime: WineRuntime) throws {
        let wineDirectory = runtime.executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let wineExecutable = wineDirectory
            .appendingPathComponent("bin/wine")
        
        let wineserverExecutable = wineDirectory
            .appendingPathComponent("bin/wineserver")
        
        guard fileManager.isExecutableFile(
            atPath: wineExecutable.path
        ) else {
            throw PrefixError.wineExecutableNotFound(
                wineExecutable
            )
        }
        
        guard fileManager.isExecutableFile(
            atPath: wineserverExecutable.path
        ) else {
            throw PrefixError.wineserverNotFound(
                wineserverExecutable
            )
        }
        
        try homeManager.prepare()
        
        var environment = ProcessInfo.processInfo.environment
        
        environment["HOME"] = homeManager.homeDirectory.path
        environment["WINEPREFIX"] = prefix.path
        environment["WINEDEBUG"] = "-all"
        environment["WINEDLLOVERRIDES"] = "mshtml=;mscoree="
        
        try WineProcessRunner.runAndValidate(
            executableURL: wineExecutable,
            arguments: ["wineboot", "-u"],
            environment: environment
        )
        
        try WineProcessRunner.runAndValidate(
            executableURL: wineserverExecutable,
            arguments: ["-w"],
            environment: environment
        )
    }
    
    private func validateStructure(prefix: URL) throws {
        let requiredFiles = [
            "system.reg",
            "user.reg",
            "userdef.reg"
        ]
        
        for file in requiredFiles {
            let fileURL = prefix.appendingPathComponent(file)
            
            guard fileManager.fileExists(
                atPath: fileURL.path
            ) else {
                throw PrefixError.invalidPrefix(
                    "Missing file: \(file)"
                )
            }
        }
        
        let driveC = prefix.appendingPathComponent(
            "drive_c",
            isDirectory: true
        )
        
        guard fileManager.fileManagerDirectoryExists(
            at: driveC
        ) else {
            throw PrefixError.invalidPrefix(
                "Missing drive_c directory"
            )
        }
    }
}

struct PrefixValidationResult: Sendable {
    let prefixURL: URL
    let issues: [String]
    var isValid: Bool {
        issues.isEmpty
    }
}

private extension FileManager {
    func fileManagerDirectoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        
        return fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
    }
}

enum PrefixError: LocalizedError {
    case alreadyExists(URL)
    case runtimeUnavailable(URL)
    case wineExecutableNotFound(URL)
    case wineserverNotFound(URL)
    case invalidPrefix(String)
    
    var errorDescription: String? {
        
        switch self {
        case .alreadyExists(let url):
            return "Prefix already exists: \(url.path)"
        case .runtimeUnavailable(let url):
            return "Wine runtime is unavailable: \(url.path)"
        case .wineExecutableNotFound(let url):
            return "Wine executable not found: \(url.path)"
        case .wineserverNotFound(let url):
            return "Wineserver not found: \(url.path)"
        case .invalidPrefix(let reason):
            return "Invalid Wine prefix: \(reason)"
        }
    }
}
