//
//  Azeroth_LauncherApp.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

@main
struct Azeroth_LauncherApp: App {
    @State private var appState = AppState()
    @State private var updaterManager = UpdaterManager()
    
    @AppStorage("AzerothLauncher.Appearance")
    private var selectedAppearance = "dark"
    
    @AppStorage("AzerothLauncher.Language")
    private var selectedLanguage = "system"

    private var appLocale: Locale {
        print("[Localization] Selected language: \(selectedLanguage)")

        if selectedLanguage == "system" {
            return .autoupdatingCurrent
        }

        return Locale(identifier: selectedLanguage)
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(appState)
                .environment(appState.gameManager)
                .environment(appState.rendererManager)
                .environment(appState.runtimeManager)
                .environment(\.locale, appLocale)
                .environment(updaterManager)
                .preferredColorScheme(
                    selectedAppearance == "dark" ? .dark : .light
                )
                .onAppear {
                    updaterManager.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 650)
    }
}
