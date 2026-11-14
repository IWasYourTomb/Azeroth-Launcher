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
                VStack(alignment: .leading, spacing: 25) {
                    rendererSection
                    generalSection
                    dllOverridesSection
                    environmentSection
                    resetSection
                    wineSection
                }
                .padding(28)
            }
            .scrollIndicators(.visible)
        }
        .frame(minWidth: 680, minHeight: 720)
        .background(LauncherTheme.background)
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
        HStack(spacing: 15) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 50, height: 50)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text("Launch Settings")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(installation.edition.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                HStack(spacing: 7) {
                    Text("Done")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 17)
                .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .tint(LauncherTheme.accent)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(LauncherTheme.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)
        }
    }

    private var rendererSection: some View {
        settingsSection(
            title: "Graphics Renderer",
            subtitle: "The graphics backend used to run your game client.",
            icon: "display"
        ) {
            HStack(spacing: 15) {
                Image(systemName: "display")
                    .font(.system(size: 23))
                    .foregroundStyle(LauncherTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(LauncherTheme.accentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 5) {
                    Text(renderer.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text(renderer.description)
                        .font(.system(size: 11))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)

                    Text("GLOBAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(LauncherTheme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(LauncherTheme.elevatedSurface)
                .clipShape(Capsule())
            }
            .padding(15)
            .background(LauncherTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var generalSection: some View {
        settingsSection(
            title: "General",
            subtitle: "Configure game startup behavior and compatibility options.",
            icon: "gamecontroller"
        ) {
            VStack(alignment: .leading, spacing: 17) {
                settingToggle(
                    title: "Enable DXVK Async",
                    subtitle: "Enable asynchronous shader compilation.",
                    icon: "bolt.fill",
                    isOn: $settings.dxvkAsyncEnabled
                )
                .disabled(renderer != .dxvk)
                .opacity(renderer == .dxvk ? 1 : 0.55)

                if renderer != .dxvk {
                    informationNotice(
                        "DXVK Async is available only when using DXVK.",
                        icon: "info.circle"
                    )
                }

                sectionDivider

                settingToggle(
                    title: "Virtual Desktop",
                    subtitle: "Run the game inside a virtual desktop window.",
                    icon: "macwindow",
                    isOn: $settings.virtualDesktopEnabled
                )

                if settings.virtualDesktopEnabled {
                    HStack(spacing: 15) {
                        resolutionField(
                            title: "Width",
                            value: $settings.virtualDesktopWidth
                        )

                        resolutionField(
                            title: "Height",
                            value: $settings.virtualDesktopHeight
                        )

                        Spacer()
                    }
                    .padding(.leading, 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                sectionDivider

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .foregroundStyle(LauncherTheme.accent)

                        Text("Launch Arguments")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LauncherTheme.primaryText)
                    }

                    Text("Enter one argument per line. These arguments are passed to the game process.")
                        .font(.system(size: 11))
                        .foregroundStyle(LauncherTheme.secondaryText)

                    TextEditor(
                        text: Binding(
                            get: {
                                settings.launchArguments.joined(separator: "\n")
                            },
                            set: {
                                settings.launchArguments = $0
                                    .components(separatedBy: .newlines)
                                    .map {
                                        $0.trimmingCharacters(in: .whitespaces)
                                    }
                                    .filter { !$0.isEmpty }
                            }
                        )
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LauncherTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(10)
                    .background(LauncherTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(LauncherTheme.separator, lineWidth: 1)
                    }
                }
            }
        }
    }
    
    private var wineSection: some View {
        settingsSection(
            title: "Wine Configuration",
            subtitle: "Configure Wine debugging and compatibility behavior.",
            icon: "wineglass"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(LauncherTheme.accent)

                    Text("Wine Debug")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LauncherTheme.primaryText)
                }

                themedTextField(
                    placeholder: "Example: -all",
                    text: $settings.wineDebug,
                    monospaced: true
                )

                Text("Controls Wine diagnostic output. Use -all to disable most debug messages.")
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }
        }
    }

    private var dllOverridesSection: some View {
        settingsSection(
            title: "DLL Overrides",
            subtitle: "Customize how Wine loads specific Windows libraries.",
            icon: "puzzlepiece"
        ) {
            VStack(alignment: .leading, spacing: 13) {
                if settings.dllOverrides.isEmpty {
                    emptyState(
                        title: "No DLL overrides",
                        description: "Custom DLL loading rules will appear here.",
                        icon: "puzzlepiece"
                    )
                } else {
                    VStack(spacing: 9) {
                        ForEach(
                            settings.dllOverrides.keys.sorted(),
                            id: \.self
                        ) { key in
                            dictionaryRow(
                                name: key,
                                value: dictionaryBinding(
                                    for: key,
                                    in: \.dllOverrides
                                ),
                                onDelete: {
                                    settings.dllOverrides.removeValue(forKey: key)
                                }
                            )
                        }
                    }
                }

                sectionDivider

                Text("ADD DLL OVERRIDE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LauncherTheme.secondaryText)

                HStack(spacing: 9) {
                    themedTextField(
                        placeholder: "DLL name",
                        text: $newDLLName,
                        monospaced: true
                    )

                    themedTextField(
                        placeholder: "Override value",
                        text: $newDLLValue,
                        monospaced: true
                    )

                    addButton {
                        addDLLOverride()
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
            VStack(alignment: .leading, spacing: 13) {
                if settings.environmentVariables.isEmpty {
                    emptyState(
                        title: "No environment variables",
                        description: "Custom environment variables will appear here.",
                        icon: "terminal"
                    )
                } else {
                    VStack(spacing: 9) {
                        ForEach(
                            settings.environmentVariables.keys.sorted(),
                            id: \.self
                        ) { key in
                            dictionaryRow(
                                name: key,
                                value: dictionaryBinding(
                                    for: key,
                                    in: \.environmentVariables
                                ),
                                onDelete: {
                                    settings.environmentVariables.removeValue(
                                        forKey: key
                                    )
                                }
                            )
                        }
                    }
                }

                sectionDivider

                Text("ADD ENVIRONMENT VARIABLE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LauncherTheme.secondaryText)

                HStack(spacing: 9) {
                    themedTextField(
                        placeholder: "Variable name",
                        text: $newEnvironmentName,
                        monospaced: true
                    )

                    themedTextField(
                        placeholder: "Value",
                        text: $newEnvironmentValue,
                        monospaced: true
                    )

                    addButton {
                        addEnvironmentVariable()
                    }
                    .disabled(
                        newEnvironmentName.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
    }

    private var resetSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 17))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 5) {
                Text("Reset Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Restore default launch settings for this edition.")
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            Button("Reset to Defaults", role: .destructive) {
                settings = .default
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(16)
        .background(LauncherTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(LauncherTheme.separator, lineWidth: 1)
        }
    }

    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(LauncherTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(LauncherTheme.accentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(LauncherTheme.secondaryText)
                }
            }

            content()
                .padding(17)
                .background(LauncherTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(LauncherTheme.separator, lineWidth: 1)
                }
        }
    }

    private func settingToggle(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(LauncherTheme.accent)
                .controlSize(.small)
        }
    }

    private func resolutionField(
        title: LocalizedStringKey,
        value: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LauncherTheme.secondaryText)

            TextField("", value: value, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(LauncherTheme.primaryText)
                .padding(.horizontal, 11)
                .frame(width: 105, height: 36)
                .background(LauncherTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(LauncherTheme.separator, lineWidth: 1)
                }
        }
    }

    private func themedTextField(
        placeholder: String,
        text: Binding<String>,
        monospaced: Bool = false
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(
                .system(
                    size: 11,
                    design: monospaced ? .monospaced : .default
                )
            )
            .foregroundStyle(LauncherTheme.primaryText)
            .padding(.horizontal, 11)
            .frame(height: 37)
            .background(LauncherTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(LauncherTheme.separator, lineWidth: 1)
            }
    }

    private func dictionaryRow(
        name: String,
        value: Binding<String>,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(LauncherTheme.accent)
                .lineLimit(1)
                .frame(width: 145, alignment: .leading)

            themedTextField(
                placeholder: "Value",
                text: value,
                monospaced: true
            )

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
                    .background(.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(9)
        .background(LauncherTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 37, height: 37)
                .background(LauncherTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(LauncherTheme.secondaryText)
                .frame(width: 38, height: 38)
                .background(LauncherTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func informationNotice(
        _ message: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(LauncherTheme.accent)

            Text(message)
                .foregroundStyle(LauncherTheme.secondaryText)
        }
        .font(.system(size: 10))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherTheme.accentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(LauncherTheme.separator)
            .frame(height: 1)
    }

    private func dictionaryBinding(
        for key: String,
        in keyPath: WritableKeyPath<GameLaunchSettings, [String: String]>
    ) -> Binding<String> {
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
