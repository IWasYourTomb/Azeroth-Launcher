//
//  SettingsView.swift
//  Azeroth Launcher
//

import SwiftUI

struct SettingsView: View {
    @Environment(RendererManager.self) private var rendererManager
    @Environment(WineRuntimeManager.self) private var runtimeManager
    @Environment(UpdaterManager.self) private var updaterManager
    @Environment(ThemeTransitionManager.self)
    private var themeTransitionManager

    @AppStorage("AzerothLauncher.Language")
    private var selectedLanguage = "system"

    @AppStorage("AzerothLauncher.Appearance")
    private var selectedAppearance = "dark"

    @State private var runtimeError: String?
    @State private var runtimeSuccess = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header

                appearanceSection
                languageSection
                graphicsSection
                updatesSection
                wineSection
            }
            .padding(30)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(
                .easeOut(duration: 0.3),
                value: selectedLanguage
            )
        }
        .background {
            ZStack {
                LauncherTheme.background

                ArcaneParticleView(
                    particleCount: 28,
                    intensity: 0.35
                )
            }
        }
        .animation(
            .easeInOut(duration: 0.55),
            value: selectedAppearance
        )
        .scrollIndicators(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Settings")
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(LauncherTheme.primaryText)

            Text("Customize your Azeroth Launcher experience.")
                .font(.system(size: 13))
                .foregroundStyle(LauncherTheme.secondaryText)
        }
        .padding(.bottom, 4)
    }

    private var appearanceSection: some View {
        settingsSection(
            title: "Appearance",
            subtitle: "Choose how Azeroth Launcher looks.",
            icon: "paintpalette"
        ) {
            HStack(spacing: 14) {
                appearanceOption(
                    title: "Light",
                    subtitle: "Bright and clean",
                    icon: "sun.max.fill",
                    value: "light"
                )

                appearanceOption(
                    title: "Dark",
                    subtitle: "Dark fantasy atmosphere",
                    icon: "moon.stars.fill",
                    value: "dark"
                )
            }
        }
    }

    private func appearanceOption(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        value: String
    ) -> some View {
        let isSelected = selectedAppearance == value

        return Button {
            themeTransitionManager.transition(
                    from: selectedAppearance,
                    to: value
                ) {
                    selectedAppearance = value
                }
        } label: {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 21))
                        .foregroundStyle(LauncherTheme.accent)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(LauncherTheme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? LauncherTheme.accentBackground
                    : LauncherTheme.elevatedSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        isSelected
                            ? LauncherTheme.accent.opacity(0.8)
                            : LauncherTheme.separator,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var languageSection: some View {
        settingsSection(
            title: "Language",
            subtitle: "Choose your launcher language.",
            icon: "globe"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "character.bubble")
                        .font(.system(size: 17))
                        .foregroundStyle(LauncherTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(LauncherTheme.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application language")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LauncherTheme.primaryText)

                        Text("Select your preferred language.")
                            .font(.system(size: 10))
                            .foregroundStyle(LauncherTheme.secondaryText)
                    }

                    Spacer()

                    Picker("Language", selection: $selectedLanguage) {
                        Text("System Default").tag("system")
                        Text("English").tag("en")
                        Text("Русский").tag("ru")
                    }
                    .frame(width: 165)
                }

                Divider()
                    .overlay(LauncherTheme.separator)

                Label(
                    "Language selection is saved automatically.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 10))
                .foregroundStyle(LauncherTheme.secondaryText)
            }
        }
    }

    private var graphicsSection: some View {
        settingsSection(
            title: "Graphics",
            subtitle: "Configure the renderer for each game edition.",
            icon: "display"
        ) {
            VStack(spacing: 12) {
                ForEach(GameEdition.allCases) { edition in
                    rendererRow(for: edition)
                }

                Label(
                    "Renderer changes apply to the selected game edition.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 10))
                .foregroundStyle(LauncherTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3)
            }
        }
    }

    private func rendererRow(for edition: GameEdition) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                Image(edition.backgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(edition.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text("Version \(edition.version)")
                        .font(.system(size: 10))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }

                Spacer()

                Picker(
                    "Renderer",
                    selection: Binding(
                        get: {
                            rendererManager.renderer(for: edition)
                        },
                        set: {
                            rendererManager.select($0, for: edition)
                        }
                    )
                ) {
                    ForEach(RendererType.allCases) { renderer in
                        Text(renderer.title)
                            .tag(renderer)
                    }
                }
                .frame(width: 175)
            }

            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                    .foregroundStyle(LauncherTheme.accent)

                Text(rendererManager.renderer(for: edition).description)
                    .foregroundStyle(LauncherTheme.secondaryText)
            }
            .font(.system(size: 10))
            .padding(.leading, 2)
        }
        .padding(13)
        .background(LauncherTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    // MARK: - Software Updates

    private var updatesSection: some View {
        settingsSection(
            title: "Software Updates",
            subtitle: "Keep Azeroth Launcher up to date.",
            icon: "arrow.down.circle"
        ) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 13) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 21))
                        .foregroundStyle(LauncherTheme.accent)
                        .frame(width: 48, height: 48)
                        .background(LauncherTheme.accentBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Azeroth Launcher")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LauncherTheme.primaryText)

                        Text("Version \(appVersion)")
                            .font(.system(size: 10))
                            .foregroundStyle(LauncherTheme.secondaryText)
                    }

                    Spacer()

                    Button {
                        updaterManager.checkForUpdates()
                    } label: {
                        HStack(spacing: 8) {
                            if updaterManager.isUpdateInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }

                            Text(
                                updaterManager.isUpdateInProgress
                                    ? "Checking..."
                                    : "Check for Updates"
                            )
                            .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LauncherTheme.accent)
                    .disabled(
                        !updaterManager.canCheckForUpdates ||
                        updaterManager.isUpdateInProgress
                    )
                }

                Divider()
                    .overlay(LauncherTheme.separator)

                Label(
                    "Updates are delivered securely through Sparkle.",
                    systemImage: "lock.shield"
                )
                .font(.system(size: 10))
                .foregroundStyle(LauncherTheme.secondaryText)
            }
        }
    }

    // MARK: - Wine Runtime

    private var wineSection: some View {
        settingsSection(
            title: "Wine Runtime",
            subtitle: "Manage compatibility layers.",
            icon: "shippingbox"
        ) {
            VStack(alignment: .leading, spacing: 13) {
                if runtimeManager.runtimes.isEmpty {
                    emptyRuntimeState
                } else {
                    ForEach(runtimeManager.runtimes) { runtime in
                        runtimeRow(runtime)
                    }
                }

                if runtimeManager.runtimes.isEmpty {
                    Button {
                        installRuntime()
                    } label: {
                        HStack(spacing: 9) {
                            if runtimeManager.isInstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }

                            Text(
                                runtimeManager.isInstalling
                                    ? "Installing Wine Runtime..."
                                    : "Install Wine Runtime"
                            )
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LauncherTheme.accent)
                    .disabled(runtimeManager.isInstalling)
                }

                if let runtimeError {
                    Label(
                        runtimeError,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if runtimeSuccess {
                    Label(
                        "Wine Runtime installed successfully.",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                }

                Divider()
                    .overlay(LauncherTheme.separator)

                Label(
                    "One Wine Runtime can be shared between multiple game installations. Each game keeps its own Prefix.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 10))
                .foregroundStyle(LauncherTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyRuntimeState: some View {
        HStack(spacing: 13) {
            Image(systemName: "shippingbox")
                .font(.system(size: 23))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 48, height: 48)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text("No Wine Runtime installed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Install a Wine Runtime to run World of Warcraft.")
                    .font(.system(size: 10))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    private func runtimeRow(_ runtime: WineRuntime) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 19))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 44, height: 44)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 5) {
                Text(runtime.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Version \(runtime.version)")
                    .font(.system(size: 10))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            if runtime.isDefault {
                Label("Default", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Button("Set Default") {
                    runtimeManager.setDefault(id: runtime.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(13)
        .background(LauncherTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    // MARK: - Shared Components

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(LauncherTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(LauncherTheme.accentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
            }

            content()
                .padding(16)
                .background(LauncherTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(LauncherTheme.separator, lineWidth: 1)
                }
        }
    }

    // MARK: - Runtime Installation

    private func installRuntime() {
        runtimeError = nil
        runtimeSuccess = false

        Task {
            do {
                try await runtimeManager.installRuntime()
                runtimeSuccess = true
                print("[Settings] Wine Runtime installed successfully")
            } catch {
                runtimeError = error.localizedDescription
                print("[Settings] Runtime installation failed: \(error)")
            }
        }
    }
}
