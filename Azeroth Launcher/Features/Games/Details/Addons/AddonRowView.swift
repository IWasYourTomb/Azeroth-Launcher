//
//  AddonRowView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct AddonRowView: View {

    let addon: GameAddon
    let edition: GameEdition

    let onToggle: (GameAddon) -> Void
    let onDelete: (GameAddon) -> Void
    let onReveal: (GameAddon) -> Void

    private var compatibility: AddonCompatibility {
        AddonCompatibility.check(
            interfaces: addon.supportedInterfaces,
            edition: edition
        )
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 17))
                .foregroundStyle(addon.isEnabled ? .orange : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    (addon.isEnabled ? Color.orange : Color.gray)
                        .opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))


            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(addon.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    if !addon.isEnabled {
                        Text("DISABLED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("v\(addon.displayVersion)")

                    Text("•")

                    Text(addon.displayAuthor)
                        .lineLimit(1)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                Text(addon.folderName)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            compatibilityBadge

            HStack(spacing: 9) {
                Button {
                    onToggle(addon)
                } label: {
                    Image(
                        systemName: addon.isEnabled
                            ? "pause.circle"
                            : "play.circle"
                    )
                    .font(.system(size: 17))
                    .foregroundStyle(
                        addon.isEnabled ? .orange : .green
                    )
                }
                .buttonStyle(.plain)
                .help(
                    addon.isEnabled
                        ? "Disable Addon"
                        : "Enable Addon"
                )

                Button {
                    onReveal(addon)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")

                Button(role: .destructive) {
                    onDelete(addon)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete Addon")
            }
        }
        .padding(12)
        .background(.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var compatibilityBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(compatibilityColor)
                .frame(width: 6, height: 6)

            Text(compatibilityTitle)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(compatibilityColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(compatibilityColor.opacity(0.1))
        .clipShape(Capsule())
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

    private var compatibilityColor: Color {
        switch compatibility {
        case .compatible:
            return .green
        case .outdated:
            return .orange
        case .newer:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
