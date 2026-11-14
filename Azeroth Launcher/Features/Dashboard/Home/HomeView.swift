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
        VStack(alignment: .leading, spacing: 28) {
            welcomeSection
            statisticsSection
            featuredGameSection
            newsSection
        }
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WELCOME TO AZEROTH")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(.orange)

            Text("Your adventure begins here")
                .font(.system(size: 28, weight: .bold))

            Text("Choose your world. Gather your allies. Make history.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statisticsSection: some View {
        HStack(spacing: 15) {
            overviewCard(
                title: "Installed games",
                value: "\(installedCount)",
                icon: "gamecontroller.fill"
            )

            overviewCard(
                title: "Available editions",
                value: "\(GameEdition.allCases.count)",
                icon: "square.grid.2x2.fill"
            )
        }
    }

    private func overviewCard(title: LocalizedStringKey,value: String,icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.orange)
                .frame(width: 42, height: 42)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var featuredGameSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.05),
                        .black.opacity(0.35),
                        .black.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        featuredInstallation == nil
                            ? "START YOUR JOURNEY"
                            : "READY TO PLAY"
                    )
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.orange)

                    Text(featuredEdition.title)
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(.white)

                    Text("Version \(featuredEdition.version)")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))

                    Button(action: onOpenGames) {
                        Label(
                            featuredInstallation == nil
                                ? "Explore Games"
                                : "Open Game Library",
                            systemImage: "arrow.right"
                        )
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 5)
                }
                .padding(25)
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("LATEST NEWS")

            HStack(spacing: 15) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 23))
                    .foregroundStyle(.orange)
                    .frame(width: 48, height: 48)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text("News and updates")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Updates from your favorite WoW realms will appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundStyle(.secondary)
    }
}
