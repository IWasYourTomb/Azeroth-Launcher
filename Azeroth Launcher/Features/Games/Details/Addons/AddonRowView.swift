//
//  AddonRowView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

import SwiftUI

struct AddonRowView: View {
    let addon: GameAddon
    let edition: GameEdition

    let onToggle: (GameAddon) -> Void
    let onDelete: (GameAddon) -> Void
    let onReveal: (GameAddon) -> Void

    @State private var isHovered = false

    private var compatibility: AddonCompatibility {
        AddonCompatibility.check(
            interfaces: addon.supportedInterfaces,
            edition: edition
        )
    }

    private var compatibilityColor: Color {
        switch compatibility {
        case .compatible:
            return .green
        case .outdated:
            return LauncherTheme.accent
        case .newer:
            return .red
        case .unknown:
            return LauncherTheme.secondaryText
        }
    }

    private var compatibilityTitle: LocalizedStringKey {
        switch compatibility {
        case .compatible:
            return "Compatible"
        case .outdated:
            return "Outdated"
        case .newer:
            return "Newer version"
        case .unknown:
            return "Unknown"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            addonIcon

            addonInformation

            Spacer(minLength: 8)

            compatibilityBadge

            actions
        }
        .padding(13)
        .background(
            isHovered
                ? LauncherTheme.elevatedSurface
                : LauncherTheme.surface
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHovered
                        ? LauncherTheme.accent.opacity(0.3)
                        : LauncherTheme.separator,
                    lineWidth: 1
                )
        }
        .animation(.easeOut(duration: 0.18), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var addonIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    addon.isEnabled
                        ? LauncherTheme.accentBackground
                        : LauncherTheme.elevatedSurface
                )

            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 19))
                .foregroundStyle(
                    addon.isEnabled
                        ? LauncherTheme.accent
                        : LauncherTheme.secondaryText
                )
        }
        .frame(width: 44, height: 44)
    }

    private var addonInformation: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(addon.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)
                    .lineLimit(1)

                if !addon.isEnabled {
                    Text("DISABLED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(LauncherTheme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(LauncherTheme.elevatedSurface)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 7) {
                Text("v\(addon.displayVersion)")

                Text("·")

                Text(addon.displayAuthor)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .foregroundStyle(LauncherTheme.secondaryText)

            Text(addon.folderName)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LauncherTheme.secondaryText.opacity(0.75))
                .lineLimit(1)
        }
    }

    private var compatibilityBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(compatibilityColor)
                .frame(width: 6, height: 6)

            Text(compatibilityTitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(compatibilityColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(compatibilityColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var actions: some View {
        HStack(spacing: 5) {
            actionButton(
                icon: addon.isEnabled ? "pause.fill" : "play.fill",
                color: addon.isEnabled ? LauncherTheme.accent : .green,
                help: addon.isEnabled ? "Disable Addon" : "Enable Addon"
            ) {
                onToggle(addon)
            }

            actionButton(
                icon: "folder",
                color: LauncherTheme.secondaryText,
                help: "Show in Finder"
            ) {
                onReveal(addon)
            }

            actionButton(
                icon: "trash",
                color: .red.opacity(0.85),
                help: "Delete Addon",
                role: .destructive
            ) {
                onDelete(addon)
            }
        }
    }

    private func actionButton(
        icon: String,
        color: Color,
        help: LocalizedStringKey,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(LauncherTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
