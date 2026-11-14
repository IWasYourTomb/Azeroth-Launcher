//
//  GameLaunchManager.swift
//  Azeroth Launcher
//
//  Created by Матвей on 08.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class GameLaunchManager {
    private let fileManager: FileManager
    private let homeManager: WineHomeManager
    private let gameConfigManager: GameConfigManager
    private let environmentValidator: EnvironmentValidator
    private let rendererInstaller: RendererInstaller
    
    private let statisticsURL: URL
    
    private(set) var environmentReport: EnvironmentValidationReport?
    private(set) var isValidatingEnvironment = false

    
    private var runningProcesses: [UUID: Process] = [:]
    private var processMonitor: Timer?
    
    private var totalPlaytimeByInstallation: [String: TimeInterval] = [:]
    private var activeSessions: [String: PlaytimeSession] = [:]
    
    private struct PlaytimeSession: Codable {
        var startedAt: Date
        var lastAccountedAt: Date
    }
    
    private struct PlaytimeStorage: Codable {
        var totalPlaytime: [String: TimeInterval]
        var activeSessions: [String: PlaytimeSession]
    }

    init(
        fileManager: FileManager = .default,
        homeManager: WineHomeManager = WineHomeManager(),
        gameConfigManager: GameConfigManager? = nil,
        environmentValidator: EnvironmentValidator? = nil,
        prefixManager: PrefixManager? = nil,
        rendererInstaller: RendererInstaller? = nil
    ) {
        self.fileManager = fileManager
        self.homeManager = homeManager
        
        self.gameConfigManager = gameConfigManager
        ?? GameConfigManager(fileManager: fileManager)
        
        let resolvedPrefixManager = prefixManager ?? PrefixManager(
            fileManager: fileManager,
            homeManager: homeManager
        )
        
        self.environmentValidator = environmentValidator
        ?? EnvironmentValidator(
            fileManager: fileManager,
            prefixManager: resolvedPrefixManager,
            homeManager: homeManager
        )
        
        self.rendererInstaller = rendererInstaller ?? RendererInstaller()
        
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
        
        self.statisticsURL = applicationSupport
            .appendingPathComponent("AzerothLauncher", isDirectory: true)
            .appendingPathComponent("Statistics", isDirectory: true)
            .appendingPathComponent("playtime.json")
        
        loadStatistics()
        recoverInterruptedSessions()
        startProcessMonitoring()
        
        print("[GameLaunchManager] Initialized")
    }
    
    func validateEnvironment(
        installation: GameInstallation,
        runtime: WineRuntime,
        renderer: RendererType
    ) async -> EnvironmentValidationReport {
        
        guard !isValidatingEnvironment else {
            if let environmentReport,
               environmentReport.installationID == installation.id {
                return environmentReport
            }
            
            return await environmentValidator.validate(
                installation: installation,
                runtime: runtime,
                renderer: renderer
            )
        }
        
        isValidatingEnvironment = true
        
        defer {
            isValidatingEnvironment = false
        }
        
        print("[GameLaunchManager] Environment validation started")
        print("[GameLaunchManager] Edition: \(installation.edition.title)")
        
        let report = await environmentValidator.validate(
            installation: installation,
            runtime: runtime,
            renderer: renderer
        )
        
        environmentReport = report
        
        print("""
        [GameLaunchManager] Environment validation finished
        
        Ready: \(report.readyCount)
        Warnings: \(report.warningCount)
        Errors: \(report.errorCount)
        """)
        
        return report
    }
    
    @discardableResult
    func launch(
        installation: GameInstallation,
        runtime: WineRuntime,
        renderer: RendererType,
        settings: GameLaunchSettings = .default
    ) throws -> Process {
        
        refreshProcessStates()
        
        if let existingProcess = runningProcesses[installation.id],
           existingProcess.isRunning {
            throw GameLaunchError.alreadyRunning
        }
        
        guard runtime.isAvailable else {
            throw GameLaunchError.runtimeUnavailable(
                runtime.executableURL
            )
        }
        
        guard fileManager.fileExists(
            atPath: installation.prefixPath.path
        ) else {
            throw GameLaunchError.prefixNotFound(
                installation.prefixPath
            )
        }
        
        let gameExecutable = installation.installationPath
            .appendingPathComponent("Wow.exe")
        
        guard fileManager.fileExists(
            atPath: gameExecutable.path
        ) else {
            throw GameLaunchError.gameExecutableNotFound(
                gameExecutable
            )
        }
        
        try homeManager.prepare()
        
        if installation.edition == .cataclysm,
           renderer == .metal {
            
            print("[GameLaunchManager] Preparing Cataclysm MTLD3D")
            
            let result = try rendererInstaller.installCataclysmMTLD3D(
                in: installation.prefixPath
            )
            
            switch result {
            case .installed:
                print("[GameLaunchManager] MTLD3D DLL installed")
                
            case .alreadyInstalled:
                print("[GameLaunchManager] MTLD3D DLL already up to date")
                
            case .restored:
                print("[GameLaunchManager] MTLD3D DLL restored")
            }
        }
        
        try gameConfigManager.prepare(for: installation)
        
        var environment = try makeEnvironment(
            installation: installation,
            runtime: runtime,
            renderer: renderer,
            settings: settings
        )
        
        let sidecarURL = Bundle.main.resourceURL?
            .appendingPathComponent("x87sidecar")
        
        if let sidecarURL,
           fileManager.isExecutableFile(atPath: sidecarURL.path) {
            
            environment["X87_SIDECAR_PATH"] = sidecarURL.path
            
            print("[GameLaunchManager] x87 Sidecar: \(sidecarURL.path)")
            
        } else {
            print("[GameLaunchManager] WARNING: x87 Sidecar not found or not executable")
        }
        
        print("[GameLaunchManager] Starting WoW")
        print("[GameLaunchManager] Edition: \(installation.edition.title)")
        print("[GameLaunchManager] Renderer: \(renderer)")
        print("[GameLaunchManager] Runtime: \(runtime.displayName)")
        print("[GameLaunchManager] Prefix: \(installation.prefixPath.path)")
        
        if let icd = environment["VK_DRIVER_FILES"] {
            print("[GameLaunchManager] Vulkan ICD: \(icd)")
        }

        let launchArguments = try makeLaunchArguments(
            gameExecutable: gameExecutable,
            settings: settings
        )
        
        let process = try WineProcessRunner.launch(
            executableURL: runtime.executableURL,
            arguments: launchArguments,
            environment: environment,
            currentDirectoryURL: installation.installationPath
        )
        
        runningProcesses[installation.id] = process
        
        let now = Date()
        
        activeSessions[installation.id.uuidString] = PlaytimeSession(
            startedAt: now,
            lastAccountedAt: now
        )
        
        saveStatistics()
        
        print("[GameLaunchManager] Wine process started: \(process.processIdentifier)")
        print("[GameLaunchManager] Playtime session started")
        
        return process
    }
    
    private func makeLaunchArguments(gameExecutable: URL, settings: GameLaunchSettings) throws -> [String] {
        
        var arguments: [String] = []
        
        if settings.virtualDesktopEnabled {
            
            let width = settings.virtualDesktopWidth
            let height = settings.virtualDesktopHeight
            
            guard (640...7680).contains(width),
                  (480...4320).contains(height) else {
                
                throw GameLaunchError.invalidVirtualDesktopResolution(
                    width: width,
                    height: height
                )
            }
            
            arguments.append("explorer")
            arguments.append(
                "/desktop=AzerothLauncher,\(width)x\(height)"
            )
        }
        
        arguments.append(gameExecutable.path)
        arguments.append(contentsOf: settings.launchArguments)
        
        return arguments
    }
    
    private func makeEnvironment(
        installation: GameInstallation,
        runtime: WineRuntime,
        renderer: RendererType,
        settings: GameLaunchSettings
    ) throws -> [String: String] {
        
        var environment: [String: String] = [
            "HOME": homeManager.homeDirectory.path,
            "WINEPREFIX": installation.prefixPath.path,
            "WINEDEBUG": settings.wineDebug,
            "WINE_LARGE_ADDRESS_AWARE": "1",
            "MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS": "1"
        ]
        
        switch renderer {
        case .dxvk:
            
            let runtimeDirectory = runtime.executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            
            let icdManifest = runtimeDirectory
                .appendingPathComponent(
                    "lib/vulkan/icd.d/MoltenVK_icd.json"
                )
            
            guard fileManager.fileExists(
                atPath: icdManifest.path
            ) else {
                throw GameLaunchError.vulkanICDNotFound(
                    icdManifest
                )
            }
            
            environment["WINEDLLOVERRIDES"] = "d3d9=n,b"
            environment["DXVK_ASYNC"] = settings.dxvkAsyncEnabled ? "1" : "0"
            environment["VK_DRIVER_FILES"] = icdManifest.path
            
        case .metal:
            
            if installation.edition == .cataclysm {
                environment["WINEDLLOVERRIDES"] = "d3d9=n,b"
            } else {
                environment["WINEDLLOVERRIDES"] = "d3d9=b"
            }
        }
        
        for (dll, override) in settings.dllOverrides {
            
            let name = dll.trimmingCharacters(in: .whitespaces)
            let value = override.trimmingCharacters(in: .whitespaces)
            
            guard !name.isEmpty, !value.isEmpty else {
                continue
            }
            
            let entry = "\(name)=\(value)"
            
            if let existing = environment["WINEDLLOVERRIDES"],
               !existing.isEmpty {
                
                environment["WINEDLLOVERRIDES"] =
                existing + ";" + entry
                
            } else {
                environment["WINEDLLOVERRIDES"] = entry
            }
        }
        
        let reservedVariables: Set<String> = [
            "HOME",
            "WINEPREFIX",
            "WINEDEBUG",
            "WINEDLLOVERRIDES",
            "DXVK_ASYNC",
            "VK_DRIVER_FILES",
            "MTLD3D_CONFIG",
            "X87_SIDECAR_PATH"
        ]
        
        for (key, value) in settings.environmentVariables {
            
            let name = key.trimmingCharacters(in: .whitespaces)
            
            guard !name.isEmpty else {
                continue
            }
            
            guard !reservedVariables.contains(name.uppercased()) else {
                
                print(
                    "[GameLaunchManager] Reserved environment variable ignored: \(name)"
                )
                
                continue
            }
            
            environment[name] = value
        }
    
        
        if renderer == .metal {
            environment["MTLD3D_CONFIG"] =
            "color.hdr.enable=false;render.scale=1.0"
            
            if installation.edition == .cataclysm {
                print("[GameLaunchManager] Cataclysm Metal profile enabled")
                print("[GameLaunchManager] Fullscreen: enabled")
            }
            
        }
        
        return environment
    }
    
    private func startProcessMonitoring() {
        guard processMonitor == nil else {
            return
        }
        
        print("[GameLaunchManager] Process monitoring started")
        
        processMonitor = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            
            Task { @MainActor [weak self] in
                self?.refreshProcessStates()
            }
        }
    }
    
    func refreshProcessStates() {
        let now = Date()
        var changed = false
        
        for (installationID, process) in Array(runningProcesses) {
            
            let key = installationID.uuidString
            
            if process.isRunning {
                
                if var session = activeSessions[key] {
                    
                    let elapsed = max(
                        0,
                        now.timeIntervalSince(session.lastAccountedAt)
                    )
                    
                    totalPlaytimeByInstallation[key, default: 0] += elapsed
                    
                    session.lastAccountedAt = now
                    activeSessions[key] = session
                    
                } else {
                    
                    activeSessions[key] = PlaytimeSession(
                        startedAt: now,
                        lastAccountedAt: now
                    )
                }
                
                changed = true
                
            } else {
                
                finishSession(
                    installationID: installationID,
                    at: now
                )
                
                print("""
                
                [GameLaunchManager] Process terminated:
                
                Installation: \(installationID)
                
                Exit code: \(process.terminationStatus)
                
                Reason: \(process.terminationReason)
                
                """)
                
                runningProcesses.removeValue(
                    forKey: installationID
                )
                
                print("[GameLaunchManager] Game process finished: \(installationID)")
                
                changed = true
            }
        }
        
        if changed {
            saveStatistics()
        }
    }
    
    func isRunning(installationID: UUID) -> Bool {
        runningProcesses[installationID]?.isRunning == true
    }
    
    func runningInstallationIDs() -> [UUID] {
        
        runningProcesses
            .filter { $0.value.isRunning }
            .map(\.key)
    }
    
    func stop(installationID: UUID) {
        
        guard let process = runningProcesses[installationID] else {
            return
        }
        
        guard process.isRunning else {
            refreshProcessStates()
            return
        }
        
        print("[GameLaunchManager] Stopping game: \(installationID)")
        
        process.terminate()
    }
    
    func totalPlaytime(for installationID: UUID) -> TimeInterval {
        
        let key = installationID.uuidString
        
        let savedTime = totalPlaytimeByInstallation[key, default: 0]
        
        guard let session = activeSessions[key] else {
            return savedTime
        }
        
        let unaccountedTime = max(
            0,
            Date().timeIntervalSince(session.lastAccountedAt)
        )
        
        return savedTime + unaccountedTime
    }
    
    func currentSessionDuration(for installationID: UUID) -> TimeInterval? {
        
        guard let session = activeSessions[installationID.uuidString] else {
            return nil
        }
        
        return max(
            0,
            Date().timeIntervalSince(session.startedAt)
        )
    }
    
    private func finishSession(installationID: UUID, at date: Date) {
        
        let key = installationID.uuidString
        
        guard let session = activeSessions.removeValue(
            forKey: key
        ) else {
            return
        }
        
        let elapsed = max(
            0,
            date.timeIntervalSince(session.lastAccountedAt)
        )
        
        totalPlaytimeByInstallation[key, default: 0] += elapsed
        
        print("[GameLaunchManager] Playtime session finished")
    }
    
    
    private func loadStatistics() {
        guard fileManager.fileExists(
            atPath: statisticsURL.path
        ) else {
            return
        }
        
        do {
            
            let data = try Data(contentsOf: statisticsURL)
            
            let storage = try JSONDecoder().decode(
                PlaytimeStorage.self,
                from: data
            )
            
            totalPlaytimeByInstallation = storage.totalPlaytime
            activeSessions = storage.activeSessions
            
            print("[GameLaunchManager] Playtime statistics loaded")
            
        } catch {
            print("[GameLaunchManager] Failed to load statistics: \(error)")
        }
    }
    
    private func saveStatistics() {
        do {
            try fileManager.createDirectory(
                at: statisticsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            let storage = PlaytimeStorage(
                totalPlaytime: totalPlaytimeByInstallation,
                activeSessions: activeSessions
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(storage)
            
            try data.write(
                to: statisticsURL,
                options: .atomic
            )
            
        } catch {
            print("[GameLaunchManager] Failed to save statistics: \(error)")
        }
    }
    
    private func recoverInterruptedSessions() {
        guard !activeSessions.isEmpty else {
            return
        }
        
        activeSessions.removeAll()
        
        saveStatistics()
        
        print("[GameLaunchManager] Recovered interrupted playtime sessions")
    }
}

enum GameLaunchError: LocalizedError {
    case alreadyRunning
    case runtimeUnavailable(URL)
    case prefixNotFound(URL)
    case gameExecutableNotFound(URL)
    case vulkanICDNotFound(URL)
    case invalidVirtualDesktopResolution(width: Int, height: Int)
    
    var errorDescription: String? {
        
        switch self {
            
        case .alreadyRunning:
            return "This game is already running."
            
        case .runtimeUnavailable(let url):
            return "Wine Runtime is unavailable: \(url.path)"
            
        case .prefixNotFound(let url):
            return "Wine Prefix not found: \(url.path)"
            
        case .gameExecutableNotFound(let url):
            return "WoW executable not found: \(url.path)"
            
        case .vulkanICDNotFound(let url):
            return "Vulkan ICD manifest not found: \(url.path)"
            
        case .invalidVirtualDesktopResolution(let width, let height):
            return """
            Invalid Wine virtual desktop resolution: \(width)x\(height).
            Supported width: 640–7680.
            Supported height: 480–4320.
            """
        }
    }
}
