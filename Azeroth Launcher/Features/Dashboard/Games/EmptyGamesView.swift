//
//  EmptyGamesView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct EmptyGamesView: View {
    let onAddGame: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LauncherTheme.accent.opacity(0.07))
                    .frame(width: 190, height: 190)

                Circle()
                    .strokeBorder(
                        LauncherTheme.accent.opacity(0.15),
                        lineWidth: 1
                    )
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(LauncherTheme.accentBackground)
                    .frame(width: 112, height: 112)

                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(LauncherTheme.accent)
                    .shadow(
                        color: LauncherTheme.accent.opacity(0.25),
                        radius: 15
                    )
            }
            .padding(.bottom, 30)

            VStack(spacing: 12) {
                Text("YOUR ADVENTURE AWAITS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(LauncherTheme.accent)

                Text("No games installed")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text("Add a World of Warcraft client to your library to get started.")
                    .font(.system(size: 13))
                    .foregroundStyle(LauncherTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 340)
            }

            Button(action: onAddGame) {
                Label("Add Game", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [
                                LauncherTheme.accent,
                                LauncherTheme.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .shadow(
                        color: LauncherTheme.accent.opacity(0.2),
                        radius: 12,
                        y: 5
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovered ? 1.04 : 1)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .padding(.top, 26)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 480)
    }
}
