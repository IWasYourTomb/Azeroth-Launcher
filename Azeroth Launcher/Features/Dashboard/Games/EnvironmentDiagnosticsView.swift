//
//  EnvironmentDiagnosticsView.swift
//  Azeroth Launcher
//
//  Created by Матвей on 14.11.2026.
//

import SwiftUI

import SwiftUI

struct EnvironmentDiagnosticsView: View {
    let report: EnvironmentValidationReport?
    let isLoading: Bool
    let onContinue: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            
            if isLoading {
                loadingContent
            } else if let report {
                diagnosticsContent(report)
            }
            
            footer
        }
        .padding(28)
        .frame(width: 560)
        .background(.background)
        .animation(.easeInOut(duration: 0.25), value: isLoading)
    }
    
    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(headerColor.opacity(0.12))
                    .frame(width: 54, height: 54)
                
                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.orange)
                } else {
                    Image(systemName: headerIcon)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(headerColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Environment Diagnostics")
                    .font(.system(size: 20, weight: .bold))
                
                Text(headerDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var headerColor: Color {
        guard let report else { return .orange }
        
        if report.hasErrors { return .red }
        if report.hasWarnings { return .orange }
        
        return .green
    }
    
    private var headerIcon: String {
        guard let report else { return "checkmark.circle.fill" }
        
        if report.hasErrors { return "xmark.circle.fill" }
        if report.hasWarnings { return "exclamationmark.triangle.fill" }
        
        return "checkmark.circle.fill"
    }
    
    private var headerDescription: LocalizedStringKey {
        if isLoading {
            return "Preparing your game environment..."
        }
        
        guard let report else {
            return "Environment check completed."
        }
        
        if report.hasErrors {
            return "Some required components are unavailable."
        }
        
        if report.hasWarnings {
            return "The environment is ready with some warnings."
        }
        
        return "Everything is ready to launch."
    }
    
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Checking game environment")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Spacer()
                    
                    Text("Please wait")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.orange)
            }
            
            VStack(alignment: .leading, spacing: 13) {
                loadingItem("Wine Runtime", icon: "wineglass")
                loadingItem("Wine Prefix", icon: "folder")
                loadingItem("Game Client", icon: "gamecontroller")
                loadingItem("Graphics Components", icon: "display")
            }
            .padding(16)
            .background(.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.vertical, 8)
    }
    
    private func loadingItem(
        _ title: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
            
            Spacer()
            
            ProgressView()
                .controlSize(.small)
                .tint(.orange)
        }
    }
    
    private func diagnosticsContent(_ report: EnvironmentValidationReport) -> some View {
        VStack(spacing: 12) {
            ForEach(report.checks) { check in
                diagnosticRow(check)
            }
        }
    }
    
    private func diagnosticRow(_ check: EnvironmentCheckResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: check.status))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color(for: check.status))
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(check.title))
                    .font(.system(size: 13, weight: .semibold))
                
                Text(LocalizedStringKey(check.details))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
    
    private func icon(for status: EnvironmentCheckStatus) -> String {
        switch status {
        case .ready: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    private func color(for status: EnvironmentCheckStatus) -> Color {
        switch status {
        case .ready: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    @ViewBuilder
    private var footer: some View {
        Divider()
        
        HStack {
            if let report, !isLoading {
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString(
                            "%lld ready · %lld warnings · %lld errors",
                            comment: "Environment diagnostics summary"
                        ),
                        report.readyCount,
                        report.warningCount,
                        report.errorCount
                    )
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !isLoading {
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
                
                if let report, !report.hasErrors {
                    Button("Continue", action: onContinue)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}
