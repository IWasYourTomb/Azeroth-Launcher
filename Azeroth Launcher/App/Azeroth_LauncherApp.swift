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

    @AppStorage("AzerothLauncher.OnboardingCompleted")
    private var onboardingCompleted = false

    private var appLocale: Locale {
        if selectedLanguage == "system" {
            return .autoupdatingCurrent
        }

        return Locale(identifier: selectedLanguage)
    }

    var body: some Scene {
        WindowGroup {
            LauncherRootView(
                onboardingCompleted: $onboardingCompleted
            )
            .environment(appState)
            .environment(appState.gameManager)
            .environment(appState.rendererManager)
            .environment(appState.runtimeManager)
            .environment(updaterManager)
            .environment(\.locale, appLocale)
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

private struct LauncherRootView: View {
    @Binding var onboardingCompleted: Bool
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    
    @State private var isSplashVisible = true
    @State private var atmosphereAnimating = false
    
    var body: some View {
        ZStack {
            LauncherTheme.background
                .ignoresSafeArea()
            
            atmosphere
            
            screenContent
                .zIndex(1)
            
            ArcaneParticleView(
                particleCount: 42,
                intensity: 0.45
            )
            .zIndex(2)
            .allowsHitTesting(false)
        }
        .clipped()
        .task {
            try? await Task.sleep(
                nanoseconds: 1_200_000_000
            )
            
            if Task.isCancelled {
                return
            }
            
            withAnimation(
                reduceMotion
                ? .linear(duration: 0.15)
                : .easeInOut(duration: 0.65)
            ) {
                isSplashVisible = false
            }
        }
        .task {
            onboardingCompleted = false
        }
        .onAppear {
            guard !reduceMotion else {
                return
            }
            
            withAnimation(
                .easeInOut(duration: 10)
                .repeatForever(autoreverses: true)
            ) {
                atmosphereAnimating = true
            }
        }
    }
    
    @ViewBuilder
    private var screenContent: some View {
        if isSplashVisible {
            SplashScreenView()
                .transition(
                    .opacity
                        .combined(
                            with: .scale(scale: reduceMotion ? 1 : 1.03)
                        )
                )
                .zIndex(2)
            
        } else if onboardingCompleted {
            DashboardView()
                .transition(
                    reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    )
                )
                .zIndex(1)
            
        } else {
            OnboardingView {
                withAnimation(
                    reduceMotion
                    ? .linear(duration: 0.15)
                    : .spring(
                        response: 0.7,
                        dampingFraction: 0.85
                    )
                ) {
                    onboardingCompleted = true
                }
            }
            .transition(
                reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity,
                    removal: .opacity
                        .combined(with: .scale(scale: 0.97))
                )
            )
            .zIndex(1)
        }
    }
    
    private var atmosphere: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(
                        LauncherTheme.accentSecondary.opacity(0.055)
                    )
                    .frame(width: 420, height: 420)
                    .blur(radius: 130)
                    .position(
                        x: geometry.size.width * (
                            atmosphereAnimating ? 0.78 : 0.9
                        ),
                        y: geometry.size.height * 0.18
                    )
                
                Circle()
                    .fill(
                        LauncherTheme.accent.opacity(0.045)
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .position(
                        x: geometry.size.width * 0.16,
                        y: geometry.size.height * (
                            atmosphereAnimating ? 0.82 : 0.68
                        )
                    )
                
                Circle()
                    .fill(
                        LauncherTheme.accentSecondary.opacity(0.025)
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .position(
                        x: geometry.size.width * 0.52,
                        y: geometry.size.height * 0.52
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
