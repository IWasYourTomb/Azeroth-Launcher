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
            return LauncherTheme.accent
        }
        
        return isInstalled ? .green : LauncherTheme.secondaryText
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
        ZStack(alignment: .top) {
            artwork
                .allowsHitTesting(false)
            
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: .black.opacity(0.35), location: 0.55),
                    .init(color: .black.opacity(0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 0) {
                statusHeader
                
                Spacer(minLength: 12)
                
                gameInformation
                
                statistics
                
                if isInstalled {
                    environmentIndicator
                        .padding(.top, 12)
                }
                
                actions
                    .padding(.top, 16)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 355)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isRunning
                    ? Color.green.opacity(0.65)
                    : .white.opacity(isHovered ? 0.35 : 0.12),
                    lineWidth: isRunning ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .shadow(
            color: isRunning
            ? .green.opacity(0.15)
            : .black.opacity(isHovered ? 0.3 : 0.16),
            radius: isHovered ? 18 : 9,
            y: 6
        )
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.25), value: isRunning)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var artwork: some View {
        GeometryReader { geometry in
            Image(edition.backgroundImageName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
                .scaleEffect(isHovered ? 1.04 : 1)
                .animation(.easeOut(duration: 0.5), value: isHovered)
        }
    }
    
    private var statusHeader: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                
                Text(statusTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.black.opacity(0.48))
            .clipShape(Capsule())
            
            Spacer()
            
            if isRunning {
                HStack(spacing: 5) {
                    Image(systemName: "waveform")
                        .font(.system(size: 9, weight: .bold))
                    
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.48))
                .clipShape(Capsule())
            }
        }
    }
    
    private var gameInformation: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(edition.title.uppercased())
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.5), radius: 5)
            
            Text("Version \(edition.version)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 15)
    }
    
    private var statistics: some View {
        HStack(spacing: 16) {
            statisticItem(
                icon: "clock",
                title: "Played",
                value: formatDuration(totalPlaytime)
            )
            
            if isRunning, let currentSessionDuration {
                statisticItem(
                    icon: "timer",
                    title: "Session",
                    value: formatSession(currentSessionDuration),
                    highlighted: true
                )
            }
            
            Spacer(minLength: 0)
        }
    }
    
    private func statisticItem(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        highlighted: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(
                    highlighted ? .green : .white.opacity(0.65)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        highlighted ? .green : .white
                    )
                    .monospacedDigit()
            }
        }
    }
    
    private var environmentIndicator: some View {
        HStack(spacing: 0) {
            environmentItem(
                title: "Client",
                isAvailable: environmentStatus?.gameClientAvailable
            )
            
            Spacer(minLength: 5)
            
            environmentItem(
                title: "Runtime",
                isAvailable: environmentStatus?.runtimeAvailable
            )
            
            Spacer(minLength: 5)
            
            environmentItem(
                title: "Prefix",
                isAvailable: prefixStatus
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 9))
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
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor(isAvailable))
                .frame(width: 6, height: 6)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
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

    private var actions: some View {
        HStack(spacing: 9) {
            if isRunning {
                Button(action: onStop) {
                    Label("STOP", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
            } else {
                Button(action: onPlay) {
                    Group {
                        if isLaunching {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                
                                Text("LAUNCHING")
                                    .tracking(1)
                            }
                        } else {
                            Label("PLAY", systemImage: "play.fill")
                                .tracking(1.5)
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(LauncherTheme.accent)
                .disabled(!isInstalled || isLaunching)
            }
            
            Button(action: onManage) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 43, height: 38)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .contentShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .disabled(!isInstalled || isLaunching)
            .help("Manage game")
        }
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
