//
//  GamesView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct GamesView: View {
    @Environment(AppState.self) private var appState
    @Environment(GameManager.self) private var gameManager
    @Environment(\.locale) private var appLocale
    let onAddGame: () -> Void
    
    @State private var selectedInstallation: GameInstallation?
    @State private var launchingInstallationID: UUID?
    @State private var runningInstallationIDs: Set<UUID> = []
    
    @State private var launchError: String?
    
    @State private var isEnvironmentValidating = false
    @State private var environmentReport: EnvironmentValidationReport?
    @State private var isDiagnosticsPresented = false
    
    @State private var pendingInstallation: GameInstallation?
    @State private var pendingRuntime: WineRuntime?
    
    @State private var environmentStatuses: [UUID: GameEnvironmentStatus] = [:]
    
    private var installedInstallations: [GameInstallation] {
        gameManager.installations
            .filter(\.isInstalled)
            .sorted {
                $0.edition.title < $1.edition.title
            }
    }
    
    var body: some View {
        Group {
            if installedInstallations.isEmpty {
                EmptyGamesView(onAddGame: onAddGame)
            } else {
                installedGames
            }
        }
        .background {
            ZStack {
                LauncherTheme.background
                
                ArcaneParticleView(
                    particleCount: 32,
                    intensity: 0.4
                )
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: installedInstallations.count
        )
        .sheet(item: $selectedInstallation) { installation in
            GameDetailsView(installation: installation)
                .environment(\.locale, appLocale)
        }
        .sheet(isPresented: $isDiagnosticsPresented) {
            if let report = environmentReport {
                EnvironmentDiagnosticsView(
                    report: report,
                    isLoading: isEnvironmentValidating,
                    onContinue: {
                        isDiagnosticsPresented = false
                        
                        guard let installation = pendingInstallation else {
                            pendingRuntime = nil
                            return
                        }
                        
                        performLaunch(installation)
                    },
                    onClose: {
                        isDiagnosticsPresented = false
                        
                        pendingInstallation = nil
                        pendingRuntime = nil
                        
                        isEnvironmentValidating = false
                        launchingInstallationID = nil
                    }
                )
                .environment(\.locale, appLocale)
            }
        }
        .alert(
            "Unable to launch game",
            isPresented: Binding(
                get: { launchError != nil },
                set: {
                    if !$0 {
                        launchError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                launchError = nil
            }
        } message: {
            Text(launchError ?? "")
        }
        .task {
            await monitorGameProcesses()
        }
    }
    
    
    private var installedGames: some View {
        VStack(alignment: .leading, spacing: 22) {
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your game library")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(LauncherTheme.primaryText)
                    
                    Text("Your installed World of Warcraft clients")
                        .font(.system(size: 12))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
                
                Spacer(minLength: 12)
                
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11))
                    
                    Text("\(installedInstallations.count)")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                    
                    Text("INSTALLED")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(LauncherTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(LauncherTheme.accentBackground)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            
            ScrollView(.vertical) {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: 420),
                            spacing: 18
                        )
                    ],
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(installedInstallations) { installation in
                        GameCardView(
                            edition: installation.edition,
                            installation: installation,
                            isLaunching: launchingInstallationID == installation.id,
                            isRunning: runningInstallationIDs.contains(installation.id),
                            totalPlaytime: appState.gameLaunchManager.totalPlaytime(
                                for: installation.id
                            ),
                            currentSessionDuration: appState.gameLaunchManager.currentSessionDuration(
                                for: installation.id
                            ),
                            environmentStatus: environmentStatuses[installation.id],
                            onPlay: {
                                launchGame(installation)
                            },
                            onStop: {
                                stopGame(installation)
                            }
                        ) {
                            selectedInstallation = installation
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func resolveRuntime(for installation: GameInstallation) throws -> WineRuntime {
        
        if let runtimeID = installation.runtimeID {
            guard let runtime = appState.runtimeManager.runtimes.first(where: {
                $0.id == runtimeID
            }) else {
                throw GamesViewError.assignedRuntimeNotFound
            }
            
            guard runtime.isAvailable else {
                throw GameLaunchError.runtimeUnavailable(
                    runtime.executableURL
                )
            }
            
            return runtime
        }
        
        guard let runtime = appState.runtimeManager.defaultRuntime else {
            throw GamesViewError.runtimeNotFound
        }
        
        guard runtime.isAvailable else {
            throw GameLaunchError.runtimeUnavailable(
                runtime.executableURL
            )
        }
        
        return runtime
    }
    
    private func refreshEnvironmentStatuses() async {
        for installation in installedInstallations {
            do {
                let runtime = try resolveRuntime(for: installation)
                
                let renderer = appState.rendererManager.renderer(
                    for: installation.edition
                )
                
                let report = await appState.gameLaunchManager.validateEnvironment(
                    installation: installation,
                    runtime: runtime,
                    renderer: renderer
                )
                
                updateEnvironmentStatus(
                    report,
                    for: installation
                )
                
            } catch {
                environmentStatuses[installation.id] = GameEnvironmentStatus(
                    gameClientAvailable: false,
                    runtimeAvailable: false,
                    prefixExists: false,
                    prefixValid: false,
                    prefixIssues: [error.localizedDescription]
                )
            }
        }
    }
    
    private func updateEnvironmentStatus(_ report: EnvironmentValidationReport, for installation: GameInstallation) {
        let checks = Dictionary(
            report.checks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        func isReady(_ id: String) -> Bool {
            checks[id]?.status == .ready
        }
        
        let prefixStructure = checks["prefix-structure"]
        
        let prefixIssues: [String] = {
            guard let check = prefixStructure,
                  check.status == .error else {
                return []
            }
            
            return [check.details]
        }()
        
        environmentStatuses[installation.id] = GameEnvironmentStatus(
            gameClientAvailable: isReady("game-executable"),
            runtimeAvailable: isReady("wine") && isReady("wineserver"),
            prefixExists: isReady("prefix"),
            prefixValid: isReady("prefix-structure"),
            prefixIssues: prefixIssues
        )
    }
    
    private func launchGame(_ installation: GameInstallation) {
        guard launchingInstallationID == nil else {
            return
        }
        
        guard !runningInstallationIDs.contains(installation.id) else {
            return
        }
        
        launchingInstallationID = installation.id
        
        environmentReport = nil
        pendingInstallation = nil
        pendingRuntime = nil
        
        isEnvironmentValidating = true
        isDiagnosticsPresented = true
        
        Task { @MainActor in
            do {
                let runtime = try resolveRuntime(for: installation)
                
                pendingRuntime = runtime
                
                print(
                    "[GamesView] Selected Runtime: \(runtime.displayName)"
                )
                
                let prefixURL = await appState.prefixManager.prefixURL(
                    for: installation.edition
                )
                
                let prefixExists = await appState.prefixManager.exists(
                    for: installation.edition
                )
                
                if !prefixExists {
                    print(
                        "[GamesView] Creating Prefix with \(runtime.displayName)"
                    )
                    
                    _ = try await appState.prefixManager.create(
                        for: installation.edition,
                        runtime: runtime
                    )
                }
                
                var launchInstallation = installation
                launchInstallation.prefixPath = prefixURL

                let renderer = appState.rendererManager.renderer(
                    for: installation.edition
                )
                
                let report = await appState.gameLaunchManager.validateEnvironment(
                    installation: launchInstallation,
                    runtime: runtime,
                    renderer: renderer
                )
                
                environmentReport = report
                pendingInstallation = launchInstallation
                
                isEnvironmentValidating = false
                
                updateEnvironmentStatus(
                    report,
                    for: launchInstallation
                )
                
                print("""
                [GamesView] Environment validation completed
                
                Edition: \(installation.edition.title)
                Runtime: \(runtime.displayName)
                Ready: \(report.readyCount)
                Warnings: \(report.warningCount)
                Errors: \(report.errorCount)
                """)
                
                if report.hasErrors || report.hasWarnings {
                    return
                }
    
                isDiagnosticsPresented = false
                
                performLaunch(launchInstallation)
                
            } catch {
                isEnvironmentValidating = false
                isDiagnosticsPresented = false
                
                pendingInstallation = nil
                pendingRuntime = nil
                
                launchingInstallationID = nil
                
                launchError = error.localizedDescription
                
                print(
                    "[GamesView] Preparation failed: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func performLaunch(_ installation: GameInstallation) {
        defer {
            launchingInstallationID = nil
            pendingInstallation = nil
            pendingRuntime = nil
        }
        
        do {
            guard let runtime = pendingRuntime else {
                throw GamesViewError.runtimeNotFound
            }
    
            guard runtime.isAvailable else {
                throw GameLaunchError.runtimeUnavailable(
                    runtime.executableURL
                )
            }
            
            let renderer = appState.rendererManager.renderer(
                for: installation.edition
            )
            
            let settings = appState.launchSettingsManager.settings(
                for: installation.edition
            )
            
            print("""
            [GamesView] Launching game
            
            Edition: \(installation.edition.title)
            Runtime: \(runtime.displayName)
            Prefix: \(installation.prefixPath.path)
            """)
            
            try appState.gameLaunchManager.launch(
                installation: installation,
                runtime: runtime,
                renderer: renderer,
                settings: settings
            )
            
            refreshRunningProcesses()
            
            print(
                "[GamesView] Launched \(installation.edition.title)"
            )
            
        } catch {
            launchError = error.localizedDescription
            
            print(
                "[GamesView] Launch failed: \(error.localizedDescription)"
            )
        }
    }
    
    private func monitorGameProcesses() async {
        await refreshEnvironmentStatuses()
        
        while !Task.isCancelled {
            refreshRunningProcesses()
            
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }
    
    private func refreshRunningProcesses() {
        runningInstallationIDs = Set(
            appState.gameLaunchManager.runningInstallationIDs()
        )
    }
    
    private func stopGame(_ installation: GameInstallation) {
        appState.gameLaunchManager.stop(
            installationID: installation.id
        )
        
        refreshRunningProcesses()
    }
}

struct GameEnvironmentStatus: Sendable {
    let gameClientAvailable: Bool
    let runtimeAvailable: Bool
    let prefixExists: Bool
    let prefixValid: Bool
    let prefixIssues: [String]
    var isReady: Bool {
        gameClientAvailable &&
        runtimeAvailable &&
        prefixExists &&
        prefixValid
    }
}

private enum GamesViewError: LocalizedError {
    case runtimeNotFound
    case assignedRuntimeNotFound
    var errorDescription: String? {
        switch self {
        case .runtimeNotFound:
            return "No Wine Runtime is selected. Please install or select a Wine Runtime in Settings."
            
        case .assignedRuntimeNotFound:
            return "The Wine Runtime assigned to this game was not found. Select another Runtime in Game Management."
        }
    }
}
