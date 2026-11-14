//
//  HomeView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct HomeView: View {
    @Environment(GameManager.self) private var gameManager

    let onOpenGames: () -> Void

    @State private var isAppeared = false
    @State private var isFeaturedHovered = false

    private var installedInstallations: [GameInstallation] {
        gameManager.installations.filter(\.isInstalled)
    }

    private var installedCount: Int {
        installedInstallations.count
    }

    private var featuredInstallation: GameInstallation? {
        installedInstallations.last
    }

    private var featuredEdition: GameEdition {
        featuredInstallation?.edition ?? .wrath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            welcomeSection

            statisticsSection

            featuredGameSection

            newsSection
        }
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 15)
        .animation(.easeOut(duration: 0.65), value: isAppeared)
        .onAppear {
            isAppeared = true
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))

                Text("WELCOME TO AZEROTH")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(3)
            }
            .foregroundStyle(LauncherTheme.accent)

            Text("Your adventure begins here")
                .font(.system(size: 31, weight: .bold, design: .serif))
                .foregroundStyle(LauncherTheme.primaryText)

            Text("Choose your world. Gather your allies. Make history.")
                .font(.system(size: 13))
                .foregroundStyle(LauncherTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var statisticsSection: some View {
        HStack(spacing: 14) {
            overviewCard(
                title: "Installed games",
                value: "\(installedCount)",
                description: "Ready for adventure",
                icon: "gamecontroller.fill",
                accent: LauncherTheme.accent
            )

            overviewCard(
                title: "Available editions",
                value: "\(GameEdition.allCases.count)",
                description: "Worlds to explore",
                icon: "globe.americas.fill",
                accent: LauncherTheme.accentSecondary
            )
        }
    }

    private func overviewCard(
        title: LocalizedStringKey,
        value: String,
        description: LocalizedStringKey,
        icon: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(accent.opacity(0.12))
                    .frame(width: 48, height: 48)

                RoundedRectangle(cornerRadius: 13)
                    .stroke(accent.opacity(0.2), lineWidth: 1)
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LauncherTheme.primaryText)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(LauncherTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(LauncherTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(LauncherTheme.separator, lineWidth: 1)
                }
        }
    }

    private var featuredGameSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle("FEATURED GAME")

            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    Image(featuredEdition.backgroundImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .scaleEffect(isFeaturedHovered ? 1.045 : 1)
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.05), location: 0),
                        .init(color: .black.opacity(0.25), location: 0.35),
                        .init(color: .black.opacity(0.85), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        .black.opacity(0.2),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(LauncherTheme.accent)
                            .frame(width: 6, height: 6)

                        Text(
                            featuredInstallation == nil
                                ? "START YOUR JOURNEY"
                                : "READY TO PLAY"
                        )
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(
                            Color(red: 1.0, green: 0.82, blue: 0.58)
                        )
                    }

                    Text(featuredEdition.title)
                        .font(.system(size: 29, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)

                    Text("Version \(featuredEdition.version)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))

                    Button(action: onOpenGames) {
                        HStack(spacing: 10) {
                            Text(
                                featuredInstallation == nil
                                    ? "Explore Games"
                                    : "Open Game Library"
                            )

                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(
                            Color(red: 0.08, green: 0.07, blue: 0.06)
                        )
                        .padding(.horizontal, 17)
                        .frame(height: 38)
                        .background {
                            LinearGradient(
                                colors: [
                                    LauncherTheme.accent,
                                    LauncherTheme.accent.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 5)
                }
                .padding(25)
            }
            .frame(height: 255)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(0.18),
                radius: 18,
                y: 8
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.35)) {
                    isFeaturedHovered = hovering
                }
            }
        }
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle("LATEST NEWS")

            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LauncherTheme.accentSecondary.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(LauncherTheme.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("News and updates")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LauncherTheme.primaryText)

                    Text("Updates from your favorite WoW realms will appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(LauncherTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LauncherTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LauncherTheme.separator, lineWidth: 1)
                    }
            }
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .tracking(2.5)
            .foregroundStyle(LauncherTheme.secondaryText)
    }
}
