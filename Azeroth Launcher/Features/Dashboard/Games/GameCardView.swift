//
//  GameCardView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import SwiftUI

struct GameCardView: View {
    let edition: GameEdition
    let installation: GameInstallation?

    let isLaunching: Bool
    let isRunning: Bool

    let totalPlaytime: TimeInterval
    let currentSessionDuration: TimeInterval?

    let environmentStatus: GameEnvironmentStatus?

    let onPlay: () -> Void
    let onStop: () -> Void
    let onManage: () -> Void

    @State private var isHovered = false

    private var isInstalled: Bool {
        installation?.isInstalled == true
    }

    private var statusColor: Color {
        if isRunning {
            return .green
        }

        if isLaunching {
            return .orange
        }

        return isInstalled ? .green : .gray
    }

    private var statusTitle: LocalizedStringKey {
        if isRunning {
            return "Running"
        }

        if isLaunching {
            return "Launching..."
        }

        return isInstalled ? "Installed" : "Not installed"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Image(edition.backgroundImageName)
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
                    .init(color: .black.opacity(0.35), location: 0.45),
                    .init(color: .black.opacity(0.92), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                Spacer()

                Text(edition.title.uppercased())
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(radius: 5)

                Text("Version \(edition.version)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 7) {
                    if isLaunching {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.orange)
                    } else {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(
                                color: statusColor.opacity(isRunning ? 0.8 : 0),
                                radius: 6
                            )
                    }

                    Text(statusTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isRunning ? .green : .white.opacity(0.85)
                        )

                    if isRunning {
                        Text("•")
                            .foregroundStyle(.green)

                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.green)
                    }
                }

                if isInstalled {
                    environmentIndicator
                }

                HStack(spacing: 7) {
                    Image(systemName: "clock")
                        .foregroundStyle(.white.opacity(0.65))

                    Text("Played")
                        .foregroundStyle(.white.opacity(0.65))

                    Text(formatDuration(totalPlaytime))
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 11))

                if isRunning, let currentSessionDuration {
                    HStack(spacing: 7) {
                        Image(systemName: "timer")
                            .foregroundStyle(.green)

                        Text("Current session")
                            .foregroundStyle(.white.opacity(0.65))

                        Text(formatSession(currentSessionDuration))
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.system(size: 11))
                }

                HStack(spacing: 10) {
                    if isRunning {
                        Button(action: onStop) {
                            Label("STOP", systemImage: "stop.fill")
                                .tracking(2)
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                    } else {
                        Button(action: onPlay) {
                            Group {
                                if isLaunching {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)

                                    Text("LAUNCHING")
                                        .tracking(1)
                                } else {
                                    Label("PLAY", systemImage: "play.fill")
                                        .tracking(2)
                                }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!isInstalled || isLaunching)
                    }

                    Button(action: onManage) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 42, height: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(!isInstalled || isLaunching)
                    .help("Manage game")
                }
            }
            .padding(20)
        }
        .frame(height: 310)
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isRunning
                        ? .green.opacity(0.55)
                        : .white.opacity(isHovered ? 0.35 : 0.08),
                    lineWidth: isRunning ? 1.5 : 1
                )
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .shadow(
            color: isRunning
                ? .green.opacity(0.12)
                : .black.opacity(isHovered ? 0.35 : 0.15),
            radius: isHovered ? 15 : 7,
            y: 5
        )
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.25), value: isRunning)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var environmentIndicator: some View {
        HStack(spacing: 12) {
            environmentItem(
                title: "Client",
                isAvailable: environmentStatus?.gameClientAvailable
            )

            environmentItem(
                title: "Runtime",
                isAvailable: environmentStatus?.runtimeAvailable
            )

            environmentItem(
                title: "Prefix",
                isAvailable: prefixStatus
            )
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .help(environmentHelp)
    }
    
    private var prefixStatus: Bool? {
        guard let environmentStatus else {
            return nil
        }

        guard environmentStatus.prefixExists else {
            return false
        }

        return environmentStatus.prefixValid
    }

    private func environmentItem(title: LocalizedStringKey, isAvailable: Bool?) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(indicatorColor(isAvailable))
                .frame(width: 6, height: 6)

            Text(title)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func indicatorColor(_ available: Bool?) -> Color {
        guard let available else {
            return .gray
        }

        return available ? .green : .red
    }

    private var environmentHelp: String {
        guard let status = environmentStatus else {
            return "Checking game environment..."
        }

        if !status.prefixIssues.isEmpty {
            return status.prefixIssues.joined(separator: "\n")
        }

        if !status.isReady {
            return "Some game environment components are unavailable."
        }

        return "Game environment is ready."
    }


    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func formatSession(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(
            format: "%02d:%02d:%02d",
            hours,
            minutes,
            seconds
        )
    }
}
