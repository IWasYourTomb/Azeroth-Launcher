//
//  SettingsView.swift
//  Azeroth Launcher
//

import SwiftUI

struct SettingsView: View {
    @Environment(RendererManager.self) private var rendererManager
    @Environment(WineRuntimeManager.self) private var runtimeManager
    @Environment(UpdaterManager.self) private var updaterManager

    @AppStorage("AzerothLauncher.Language")
    private var selectedLanguage = "system"

    @AppStorage("AzerothLauncher.Appearance")
    private var selectedAppearance = "dark"

    @State private var runtimeError: String?
    @State private var runtimeSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                appearanceSection
                Divider()
                languageSection
                Divider()
                graphicsSection
                Divider()
                updatesSection
                Divider()
                wineSection
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }


    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))

            Text("Customize your Azeroth Launcher experience.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Appearance",
                subtitle: "Choose how Azeroth Launcher looks.",
                icon: "paintpalette"
            )

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
                    icon: "moon.fill",
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
            selectedAppearance = value
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? Color.orange.opacity(0.10)
                    : Color.primary.opacity(0.035)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.orange : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Language",
                subtitle: "Choose your launcher language.",
                icon: "globe"
            )

            HStack {
                Label(
                    "Application language",
                    systemImage: "character.bubble"
                )
                .font(.system(size: 13, weight: .medium))

                Spacer()

                Picker("Language", selection: $selectedLanguage) {
                    Text("System Default").tag("system")
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }
                .frame(width: 180)
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Language selection is saved automatically.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var graphicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Graphics",
                subtitle: "Configure the renderer for each game edition.",
                icon: "display"
            )

            ForEach(GameEdition.allCases) { edition in
                rendererRow(for: edition)
            }

            Text("Renderer changes apply to the selected game edition.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func rendererRow(for edition: GameEdition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(edition.title)
                        .font(.system(size: 13, weight: .semibold))

                    Text("Version \(edition.version)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
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
                .frame(width: 190)
            }

            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)

                Text(rendererManager.renderer(for: edition).description)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Software Updates",
                subtitle: "Keep Azeroth Launcher up to date.",
                icon: "arrow.down.circle"
            )

            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                    .frame(width: 46, height: 46)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Azeroth Launcher")
                        .font(.system(size: 13, weight: .semibold))

                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
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
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(
                    !updaterManager.canCheckForUpdates ||
                    updaterManager.isUpdateInProgress
                )
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Updates are delivered securely through Sparkle.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var wineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Wine Runtime",
                subtitle: "Manage compatibility layers.",
                icon: "shippingbox"
            )

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
                            Image(systemName: "arrow.down.circle")
                        }

                        Text(
                            runtimeManager.isInstalling
                                ? "Installing Wine Runtime..."
                                : "Install Wine Runtime"
                        )
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
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

            Text("One Wine Runtime can be shared between multiple game installations. Each game keeps its own Prefix.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyRuntimeState: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
                .frame(width: 46, height: 46)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text("No Wine Runtime installed")
                    .font(.system(size: 13, weight: .semibold))

                Text("Install a Wine Runtime to run World of Warcraft.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func runtimeRow(_ runtime: WineRuntime) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
                .frame(width: 42, height: 42)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(runtime.name)
                    .font(.system(size: 13, weight: .semibold))

                Text("Version \(runtime.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if runtime.isDefault {
                Label("Default", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Button("Set Default") {
                    runtimeManager.setDefault(id: runtime.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(.orange)
                .frame(width: 42, height: 42)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
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
