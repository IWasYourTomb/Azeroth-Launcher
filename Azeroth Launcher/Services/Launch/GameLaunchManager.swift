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
    private let prefixManager: PrefixManager

    private let statisticsURL: URL
    private let statisticsSaveInterval: TimeInterval = 15
    private var lastStatisticsSaveAt = Date()

    private(set) var environmentReport: EnvironmentValidationReport?
    private(set) var isValidatingEnvironment = false

    private var runningProcesses: [UUID: Process] = [:]
    private var processMonitor: Timer?

    private var totalPlaytimeByInstallation: [String: TimeInterval] = [:]
    private var activeSessions: [String: PlaytimeSession] = [:]

    private(set) var activeInstallationIDs: Set<UUID> = []
    private(set) var stoppingInstallationIDs: Set<UUID> = []

    private struct PlaytimeSession: Codable {

        var startedAt: Date
        var lastAccountedAt: Date

        var runtimeID: UUID? = nil
        var prefixURL: URL? = nil
        var wineserverURL: URL? = nil
        var homeDirectory: URL? = nil
    }

    private struct WineProcessContext {

        let wineserverURL: URL
        let prefixURL: URL
        let homeDirectory: URL
    }

    private struct PlaytimeStorage: Codable {

        var totalPlaytime: [String: TimeInterval]
        var activeSessions: [String: PlaytimeSession]
    }

    private var processContexts: [UUID: WineProcessContext] = [:]
    private var sessionMonitors: [UUID: WineSessionMonitor] = [:]

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

        self.prefixManager = resolvedPrefixManager

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

        if activeInstallationIDs.contains(installation.id) ||
            sessionMonitors[installation.id]?.isRunning == true {
            throw GameLaunchError.alreadyRunning
        }

        guard runtime.isAvailable else {
            throw GameLaunchError.runtimeUnavailable(
                runtime.executableURL
            )
        }

        guard let wineserverURL = runtime.wineserverURL else {
            throw GameLaunchError.wineserverNotFound(
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

        environment["WINESERVER"] = wineserverURL.path

        let wineServerEnvironment = [
            "HOME": homeManager.homeDirectory.path,
            "WINEPREFIX": installation.prefixPath.path,
            "WINESERVER": wineserverURL.path
        ]

        print("[GameLaunchManager] Initializing Wine Server")

        try WineProcessRunner.runAndValidate(
            executableURL: wineserverURL,
            arguments: ["-p3"],
            environment: wineServerEnvironment
        )

        print("[GameLaunchManager] Wine Server initialized")

        let process = try WineProcessRunner.launch(
            executableURL: runtime.executableURL,
            arguments: launchArguments,
            environment: environment,
            currentDirectoryURL: installation.installationPath
        )

        let monitor = try WineSessionMonitor.start(
            wineserverURL: wineserverURL,
            prefixURL: installation.prefixPath,
            homeDirectory: homeManager.homeDirectory
        )

        let context = WineProcessContext(
            wineserverURL: wineserverURL,
            prefixURL: installation.prefixPath,
            homeDirectory: homeManager.homeDirectory
        )

        runningProcesses[installation.id] = process
        sessionMonitors[installation.id] = monitor
        processContexts[installation.id] = context

        activeInstallationIDs.insert(installation.id)

        let now = Date()

        activeSessions[installation.id.uuidString] = PlaytimeSession(
            startedAt: now,
            lastAccountedAt: now,
            runtimeID: runtime.id,
            prefixURL: installation.prefixPath,
            wineserverURL: wineserverURL,
            homeDirectory: homeManager.homeDirectory
        )

        saveStatistics(force: true)

        print("[GameLaunchManager] Wine process started: \(process.processIdentifier)")
        print("[GameLaunchManager] Playtime session started")

        return process
    }

    func recoverSessions(installations: [GameInstallation], runtimes: [WineRuntime], defaultRuntime: WineRuntime?) async {

        guard !activeSessions.isEmpty else {
            print("[GameLaunchManager] No interrupted sessions to recover")
            return
        }

        print("[GameLaunchManager] Recovering interrupted sessions")

        let sessionsToRecover = activeSessions

        var recoveredCount = 0
        var closedCount = 0

        for (key, var session) in sessionsToRecover {

            guard let installationID = UUID(uuidString: key) else {
                activeSessions.removeValue(forKey: key)
                continue
            }

            guard let installation = installations.first(
                where: { $0.id == installationID && $0.isInstalled }
            ) else {

                closeInterruptedSession(
                    installationID: installationID,
                    session: session
                )

                closedCount += 1
                continue
            }

            let runtime: WineRuntime?

            if let savedRuntimeID = session.runtimeID {

                runtime = runtimes.first {
                    $0.id == savedRuntimeID
                }

            } else if let assignedRuntimeID = installation.runtimeID {

                runtime = runtimes.first {
                    $0.id == assignedRuntimeID
                }

            } else {

                runtime = defaultRuntime
            }

            guard let runtime,
                  runtime.isAvailable,
                  let wineserverURL = runtime.wineserverURL else {

                print("[GameLaunchManager] Cannot recover Runtime for \(installationID)")

                closeInterruptedSession(
                    installationID: installationID,
                    session: session
                )

                closedCount += 1
                continue
            }

            let prefixURL = await prefixManager.prefixURL(
                for: installation.edition
            )

            guard fileManager.fileExists(
                atPath: prefixURL.path
            ) else {

                print("[GameLaunchManager] Prefix missing: \(prefixURL.path)")

                closeInterruptedSession(
                    installationID: installationID,
                    session: session
                )

                closedCount += 1
                continue
            }

            let homeDirectory = session.homeDirectory
                ?? homeManager.homeDirectory

            guard fileManager.fileExists(
                atPath: homeDirectory.path
            ) else {

                print("[GameLaunchManager] Wine Home missing: \(homeDirectory.path)")

                closeInterruptedSession(
                    installationID: installationID,
                    session: session
                )

                closedCount += 1
                continue
            }

            do {

                guard let monitor = try await WineSessionMonitor.attachIfRunning(
                    wineserverURL: wineserverURL,
                    prefixURL: prefixURL,
                    homeDirectory: homeDirectory
                ) else {

                    closeInterruptedSession(
                        installationID: installationID,
                        session: session
                    )

                    closedCount += 1
                    continue
                }

                let now = Date()

                session.lastAccountedAt = now
                session.runtimeID = runtime.id
                session.prefixURL = prefixURL
                session.wineserverURL = wineserverURL
                session.homeDirectory = homeDirectory

                activeSessions[key] = session

                sessionMonitors[installationID] = monitor

                processContexts[installationID] = WineProcessContext(
                    wineserverURL: wineserverURL,
                    prefixURL: prefixURL,
                    homeDirectory: homeDirectory
                )

                activeInstallationIDs.insert(installationID)

                recoveredCount += 1

                print("""
                [GameLaunchManager] Session recovered:
                Installation: \(installationID)
                Runtime: \(runtime.displayName)
                Prefix: \(prefixURL.path)
                Monitor PID: \(monitor.isRunning)
                """)

            } catch {

                print("""
                [GameLaunchManager] Recovery failed:
                Installation: \(installationID)
                Error: \(error.localizedDescription)
                """)

                closeInterruptedSession(
                    installationID: installationID,
                    session: session
                )

                closedCount += 1
            }
        }

        saveStatistics(force: true)

        print("""
        [GameLaunchManager] Recovery completed

        Recovered: \(recoveredCount)
        Closed: \(closedCount)
        """)
    }

    private func closeInterruptedSession(
        installationID: UUID,
        session: PlaytimeSession
    ) {

        let key = installationID.uuidString

        activeSessions.removeValue(forKey: key)

        let elapsed = max(
            0,
            session.lastAccountedAt.timeIntervalSince(session.startedAt)
        )

        print("[GameLaunchManager] Interrupted session closed: \(installationID)")
        print("[GameLaunchManager] Last accounted: \(session.lastAccountedAt)")
        print("[GameLaunchManager] Session elapsed before interruption: \(elapsed)")
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
            "WINESERVER",
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
        var sessionFinished = false

        for (installationID, monitor) in Array(sessionMonitors) {

            guard !monitor.isRunning else {
                activeInstallationIDs.insert(installationID)

                if var session = activeSessions[installationID.uuidString] {

                    let elapsed = max(
                        0,
                        now.timeIntervalSince(session.lastAccountedAt)
                    )

                    totalPlaytimeByInstallation[
                        installationID.uuidString,
                        default: 0
                    ] += elapsed

                    session.lastAccountedAt = now
                    activeSessions[installationID.uuidString] = session

                } else {
                    activeSessions[installationID.uuidString] = PlaytimeSession(
                        startedAt: now,
                        lastAccountedAt: now
                    )
                }

                changed = true
                continue
            }

            finishSession(
                installationID: installationID,
                at: now
            )

            activeInstallationIDs.remove(installationID)

            let exitCode = monitor.terminationStatus

            print("""
            [GameLaunchManager] Wine session finished:
            Installation: \(installationID)
            Monitor exit code: \(exitCode.map(String.init) ?? "unknown")
            """)

            runningProcesses.removeValue(forKey: installationID)
            processContexts.removeValue(forKey: installationID)
            sessionMonitors.removeValue(forKey: installationID)

            print("[GameLaunchManager] Wine session stopped: \(installationID)")

            changed = true
            sessionFinished = true
        }

        if changed {
            saveStatistics(force: sessionFinished)
        }
    }

    func stop(installationID: UUID) {

        guard !stoppingInstallationIDs.contains(installationID),
              activeInstallationIDs.contains(installationID),
              let context = processContexts[installationID],
              sessionMonitors[installationID]?.isRunning == true else {
            return
        }

        stoppingInstallationIDs.insert(installationID)

        print("[GameLaunchManager] Stopping Wine session")
        print("[GameLaunchManager] Prefix: \(context.prefixURL.path)")

        Task { @MainActor [weak self] in

            guard let self else {
                return
            }

            defer {
                self.stoppingInstallationIDs.remove(installationID)
            }

            do {

                try await Task.detached(priority: .userInitiated) {

                    try WineProcessRunner.runAndValidate(
                        executableURL: context.wineserverURL,
                        arguments: ["-k"],
                        environment: [
                            "HOME": context.homeDirectory.path,
                            "WINEPREFIX": context.prefixURL.path
                        ]
                    )

                }.value

                print("[GameLaunchManager] wineserver -k completed")

            } catch {

                print("[GameLaunchManager] wineserver shutdown failed: \(error.localizedDescription)")
            }

            for _ in 0..<100 {

                guard sessionMonitors[installationID]?.isRunning == true else {
                    break
                }

                try? await Task.sleep(for: .milliseconds(100))
            }

            if sessionMonitors[installationID]?.isRunning == true {
                print("[GameLaunchManager] WARNING: Wine session did not stop in time")
            }

            refreshProcessStates()
        }
    }

    func isRunning(installationID: UUID) -> Bool {
        activeInstallationIDs.contains(installationID)
    }

    func runningInstallationIDs() -> [UUID] {
        Array(activeInstallationIDs)
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

    private func saveStatistics(force: Bool = false) {
        let now = Date()

        guard force ||
              now.timeIntervalSince(lastStatisticsSaveAt) >= statisticsSaveInterval else {
            return
        }

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

            lastStatisticsSaveAt = now

            print("[GameLaunchManager] Statistics saved")

        } catch {
            print("[GameLaunchManager] Failed to save statistics: \(error)")
        }
    }
    
    func isRuntimeInUse(_ runtimeID: UUID) -> Bool {
            refreshProcessStates()
            return activeSessions.values.contains {
                $0.runtimeID == runtimeID
            }
        }
}

enum GameLaunchError: LocalizedError {

    case alreadyRunning
    case runtimeUnavailable(URL)
    case prefixNotFound(URL)
    case gameExecutableNotFound(URL)
    case vulkanICDNotFound(URL)
    case invalidVirtualDesktopResolution(width: Int, height: Int)
    case wineserverNotFound(URL)

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

        case .wineserverNotFound(let url):
            return "Wine wineserver executable not found near: \(url.path)"
        }
    }
}
