//
//  GameDetailsView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI
import AppKit

struct GameDetailsView: View {
    let installation: GameInstallation

    @Environment(\.locale) private var appLocale
    @Environment(\.dismiss) private var dismiss

    @State private var copiedValue: String?
    @State private var isRealmManagerPresented = false
    @State private var currentRealmAddress: String?
    @State private var savedRealms: [RealmServer] = []
    @State private var isLaunchSettingsPresented = false

    private let realmFileService = RealmListFileService()
    private let realmStore = RealmServerStore()

    private var currentRealm: RealmServer? {
        guard let currentRealmAddress else {
            return nil
        }

        return savedRealms.first {
            $0.address.caseInsensitiveCompare(currentRealmAddress) == .orderedSame
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    heroSection

                    installationSection

                    launchSettingsSection

                    realmSection

                    addonsSection
                }
                .padding(28)
                .frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
            }
            .background(LauncherTheme.background)
        }
        .frame(minWidth: 850, minHeight: 650)
        .background(LauncherTheme.background)
        .sheet(isPresented: $isLaunchSettingsPresented) {
            GameLaunchSettingsView(installation: installation)
                .environment(\.locale, appLocale)
        }
        .sheet(
            isPresented: $isRealmManagerPresented,
            onDismiss: loadCurrentRealm
        ) {
            RealmListView(installation: installation)
                .environment(\.locale, appLocale)
        }
        .onAppear {
            loadCurrentRealm()
        }
    }


    private var header: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(LauncherTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(LauncherTheme.separator, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help("Back to Games")

            VStack(alignment: .leading, spacing: 3) {
                Text("Game Management")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Manage your game installation")
                    .font(.system(size: 10))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)

                Text("INSTALLED")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LauncherTheme.secondaryText)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(LauncherTheme.surface)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 15)
        .background(LauncherTheme.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LauncherTheme.separator)
                .frame(height: 1)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Image(installation.edition.backgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.05), location: 0),
                    .init(color: .black.opacity(0.2), location: 0.35),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))

                    Text("GAME CLIENT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2.5)
                }
                .foregroundStyle(LauncherTheme.accentSecondary)

                Text(installation.edition.title)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8)

                HStack(spacing: 12) {
                    Label(
                        "Version \(installation.edition.version)",
                        systemImage: "number"
                    )

                    Rectangle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 1, height: 12)

                    Label("Installed", systemImage: "checkmark.circle.fill")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(26)
        }
        .frame(height: 235)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
    }

    private var installationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Installation",
                subtitle: "Game client information",
                icon: "folder.fill"
            )

            VStack(spacing: 0) {
                infoRow(
                    title: "Game directory",
                    value: installation.installationPath.path,
                    icon: "folder"
                )

                Rectangle()
                    .fill(LauncherTheme.separator)
                    .frame(height: 1)
                    .padding(.leading, 48)

                infoRow(
                    title: "Wine Prefix",
                    value: installation.prefixPath.path,
                    icon: "shippingbox"
                )
            }
            .background(LauncherTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(LauncherTheme.separator, lineWidth: 1)
            }
        }
    }

    // MARK: - Launch Configuration

    private var launchSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Launch Configuration",
                subtitle: "Configure how this game client starts",
                icon: "slider.horizontal.3"
            )

            Button {
                isLaunchSettingsPresented = true
            } label: {
                HStack(spacing: 14) {
                    sectionIcon(
                        "gearshape.2.fill",
                        color: LauncherTheme.accent
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Launch Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LauncherTheme.primaryText)

                        Text("Renderer, Wine, arguments and environment")
                            .font(.system(size: 11))
                            .foregroundStyle(LauncherTheme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LauncherTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(LauncherTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                .padding(15)
                .background(LauncherTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(LauncherTheme.separator, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Realm

    private var realmSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                "Realm Configuration",
                subtitle: "Manage your game server connection",
                icon: "server.rack"
            )

            HStack(spacing: 14) {
                sectionIcon(
                    "network",
                    color: LauncherTheme.accentSecondary
                )

                VStack(alignment: .leading, spacing: 6) {
                    Group {
                        if let currentRealm {
                            Text(currentRealm.name)
                        } else if currentRealmAddress != nil {
                            Text("Custom Realm")
                        } else {
                            Text("Not configured")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                    if let currentRealmAddress {
                        Text(currentRealmAddress)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(LauncherTheme.secondaryText)
                            .textSelection(.enabled)
                            .lineLimit(1)
                    } else {
                        Text("No game server address configured")
                            .font(.system(size: 11))
                            .foregroundStyle(LauncherTheme.secondaryText)
                    }
                }

                Spacer(minLength: 8)

                Circle()
                    .fill(currentRealmAddress == nil ? .gray : .green)
                    .frame(width: 8, height: 8)

                Button {
                    isRealmManagerPresented = true
                } label: {
                    Label(
                        "Manage",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(LauncherTheme.accent)
            }
            .padding(15)
            .background(LauncherTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(LauncherTheme.separator, lineWidth: 1)
            }
        }
    }

    // MARK: - Addons

    private var addonsSection: some View {
        AddonsView(installation: installation)
    }

    // MARK: - Components

    private func sectionHeader(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 38, height: 38)
                .background(LauncherTheme.accentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }
        }
    }

    private func sectionIcon(
        _ name: String,
        color: Color
    ) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func infoRow(
        title: LocalizedStringKey,
        value: String,
        icon: String
    ) -> some View {
        let isCopied = copiedValue == value

        return HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LauncherTheme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LauncherTheme.secondaryText)

                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LauncherTheme.primaryText)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 5)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    copiedValue = value
                }

                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)

                    if copiedValue == value {
                        withAnimation(.easeOut(duration: 0.2)) {
                            copiedValue = nil
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))

                    if isCopied {
                        Text("Copied")
                            .font(.system(size: 10, weight: .semibold))
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .foregroundStyle(
                    isCopied ? Color.green : LauncherTheme.secondaryText
                )
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    isCopied
                        ? Color.green.opacity(0.1)
                        : LauncherTheme.elevatedSurface
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(isCopied ? "Copied to clipboard" : "Copy to clipboard")
            .accessibilityLabel(
                isCopied ? "Copied to clipboard" : "Copy to clipboard"
            )
        }
        .padding(14)
        .contentShape(Rectangle())
    }


    private func loadCurrentRealm() {
        savedRealms = realmStore.load(for: installation.edition)

        do {
            currentRealmAddress = try realmFileService.readCurrentRealm(
                installationPath: installation.installationPath
            )
        } catch {
            currentRealmAddress = nil
            print("Failed to read current realm: \(error.localizedDescription)")
        }
    }
}
