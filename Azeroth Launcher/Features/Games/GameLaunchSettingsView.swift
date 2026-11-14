//
//  GameLaunchSettingsView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import SwiftUI

struct GameLaunchSettingsView: View {
    let installation: GameInstallation

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var settings = GameLaunchSettings.default

    @State private var newDLLName = ""
    @State private var newDLLValue = ""

    @State private var newEnvironmentName = ""
    @State private var newEnvironmentValue = ""

    private var renderer: RendererType {
        appState.rendererManager.renderer(for: installation.edition)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    rendererSection
                    generalSection
                    wineSection
                    dllOverridesSection
                    environmentSection
                    resetSection
                }
                .padding(26)
            }
        }
        .frame(minWidth: 650, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            settings = appState.launchSettingsManager.settings(
                for: installation.edition
            )
        }
        .onChange(of: settings) { _, newValue in
            appState.launchSettingsManager.update(
                newValue,
                for: installation.edition
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Launch Settings")
                    .font(.system(size: 20, weight: .bold))

                Text(installation.edition.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }

    private var rendererSection: some View {
        settingsSection(
            title: "Graphics Renderer",
            subtitle: "The renderer is configured in application settings.",
            icon: "display"
        ) {
            HStack(spacing: 14) {
                Image(systemName: "display")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 5) {
                    Text(renderer.title)
                        .font(.system(size: 14, weight: .semibold))

                    Text(renderer.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("GLOBAL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            .padding(15)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var generalSection: some View {
        settingsSection(
            title: "General",
            subtitle: "Configure game startup behavior.",
            icon: "gamecontroller"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(
                    "Enable DXVK Async",
                    isOn: $settings.dxvkAsyncEnabled
                )
                .disabled(renderer != .dxvk)

                if renderer != .dxvk {
                    Text("DXVK Async is available only when using DXVK.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                Toggle(
                    "Virtual Desktop",
                    isOn: $settings.virtualDesktopEnabled
                )

                if settings.virtualDesktopEnabled {
                    HStack {
                        resolutionField(
                            title: "Width",
                            value: $settings.virtualDesktopWidth
                        )

                        resolutionField(
                            title: "Height",
                            value: $settings.virtualDesktopHeight
                        )
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Launch Arguments")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Enter one argument per line.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextEditor(
                        text: Binding(
                            get: {
                                settings.launchArguments.joined(separator: "\n")
                            },
                            set: {
                                settings.launchArguments = $0
                                    .components(separatedBy: .newlines)
                                    .map { $0.trimmingCharacters(in: .whitespaces) }
                                    .filter { !$0.isEmpty }
                            }
                        )
                    )
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 85)
                    .padding(5)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var wineSection: some View {
        settingsSection(
            title: "Wine Configuration",
            subtitle: "Configure Wine debugging and compatibility.",
            icon: "wineglass"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Wine Debug")
                    .font(.system(size: 12, weight: .semibold))

                TextField("Example: -all", text: $settings.wineDebug)
                    .textFieldStyle(.roundedBorder)

                Text("Controls Wine diagnostic output.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dllOverridesSection: some View {
        settingsSection(
            title: "DLL Overrides",
            subtitle: "Configure custom DLL loading behavior.",
            icon: "puzzlepiece"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if settings.dllOverrides.isEmpty {
                    emptyState("No custom DLL overrides.")
                }

                ForEach(settings.dllOverrides.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 130, alignment: .leading)

                        TextField(
                            "Override value",
                            text: dictionaryBinding(
                                for: key,
                                in: \.dllOverrides
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Button(role: .destructive) {
                            settings.dllOverrides.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Divider()

                HStack {
                    TextField("DLL name", text: $newDLLName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Value", text: $newDLLValue)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        addDLLOverride()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(
                        newDLLName.trimmingCharacters(in: .whitespaces).isEmpty ||
                        newDLLValue.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
    }

    private var environmentSection: some View {
        settingsSection(
            title: "Environment Variables",
            subtitle: "Additional variables passed to the game process.",
            icon: "terminal"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if settings.environmentVariables.isEmpty {
                    emptyState("No custom environment variables.")
                }

                ForEach(settings.environmentVariables.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 150, alignment: .leading)

                        TextField(
                            "Value",
                            text: dictionaryBinding(
                                for: key,
                                in: \.environmentVariables
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Button(role: .destructive) {
                            settings.environmentVariables.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Divider()

                HStack {
                    TextField(
                        "Variable name",
                        text: $newEnvironmentName
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        "Value",
                        text: $newEnvironmentValue
                    )
                    .textFieldStyle(.roundedBorder)

                    Button {
                        addEnvironmentVariable()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(
                        newEnvironmentName.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
    }

    private var resetSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reset Settings")
                    .font(.system(size: 12, weight: .semibold))

                Text("Restore default launch settings for this edition.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset to Defaults", role: .destructive) {
                settings = .default
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.orange)
                    .frame(width: 40, height: 40)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            content()
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func resolutionField(title: LocalizedStringKey, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField(
                "",
                value: value,
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
        }
    }

    private func emptyState(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.vertical, 5)
    }

    private func dictionaryBinding(for key: String,in keyPath: WritableKeyPath<GameLaunchSettings, [String: String]>) -> Binding<String> {
        Binding(
            get: {
                settings[keyPath: keyPath][key] ?? ""
            },
            set: { newValue in
                settings[keyPath: keyPath][key] = newValue
            }
        )
    }

    private func addDLLOverride() {
        let name = newDLLName.trimmingCharacters(in: .whitespaces)
        let value = newDLLValue.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty, !value.isEmpty else {
            return
        }

        settings.dllOverrides[name] = value

        newDLLName = ""
        newDLLValue = ""
    }

    private func addEnvironmentVariable() {
        let name = newEnvironmentName.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            return
        }

        settings.environmentVariables[name] = newEnvironmentValue

        newEnvironmentName = ""
        newEnvironmentValue = ""
    }
}
