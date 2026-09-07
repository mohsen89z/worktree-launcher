import AppKit
import SwiftUI
import WorktreeLauncherCore

public struct MenuBarView: View {
    @ObservedObject private var viewModel: LauncherViewModel
    private let loginItemController: LoginItemController

    public init(viewModel: LauncherViewModel, loginItemController: LoginItemController) {
        self.viewModel = viewModel
        self.loginItemController = loginItemController
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.records) { record in
                            recordRow(record)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 390)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !viewModel.logPreview.isEmpty {
                Text(viewModel.logPreview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            footer
        }
        .padding(16)
        .frame(width: 430)
        .background(background)
        .onAppear { viewModel.refresh() }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.regularMaterial)
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [.blue.opacity(0.22), .green.opacity(0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: AppIcon.systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("Worktree Launcher")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Local apps, ports, logs, restarts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No apps registered", systemImage: "sparkles")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Register a worktree app with `wt-launch` and it will appear here with URL, port, logs, and restart controls.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("wt-launch register --name web-app --cwd … --command … --start")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.14), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func recordRow(_ record: AppRecord) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    statusDot(record.status)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text(URL(fileURLWithPath: record.cwd).lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(webApplications(for: record)) { app in
                        labeledOpenButton(app)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                actionButton("Start", "play.fill", disabled: record.status == .running) { viewModel.start(recordID: record.id) }
                actionButton("Stop", "stop.fill", disabled: record.status != .running) { viewModel.stop(recordID: record.id) }
                actionButton("Restart", "arrow.clockwise", disabled: false) { viewModel.restart(recordID: record.id) }
                actionButton("Logs", "doc.text", disabled: false) { viewModel.showLogs(recordID: record.id) }
                actionButton("Remove", "xmark", disabled: false, destructive: true) { viewModel.remove(recordID: record.id) }
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func labeledOpenButton(_ app: WebApplication) -> some View {
        Button {
            guard let url = URL(string: app.url) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Label("Open \(app.label)", systemImage: "safari")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Open \(app.label)")
    }

    private func actionButton(_ title: String, _ systemImage: String, disabled: Bool, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(destructive ? .red : .primary)
                .background(.white.opacity(disabled ? 0.04 : 0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .help(title)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label(loginItemController.statusDescription, systemImage: "power.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.white.opacity(0.08), in: Capsule())
            Spacer()
            Button("Login Items") { loginItemController.openSystemSettings() }
                .buttonStyle(.link)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.link)
        }
    }

    private func webApplications(for record: AppRecord) -> [WebApplication] {
        if !record.webApplications.isEmpty {
            return record.webApplications
        }
        if let url = record.url {
            return [WebApplication(label: record.name, url: url)]
        }
        return record.ports.map { WebApplication(label: "Port \($0)", url: "http://localhost:\($0)") }
    }

    private func statusText(_ record: AppRecord) -> String {
        if !record.pids.isEmpty, record.status == .running {
            return "pids \(record.pids.map(String.init).joined(separator: ","))"
        }
        return record.status.rawValue
    }

    private func statusDot(_ status: AppRuntimeStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 9, height: 9)
            .shadow(color: statusColor(status).opacity(0.7), radius: status == .running ? 4 : 0)
    }

    private func statusColor(_ status: AppRuntimeStatus) -> Color {
        switch status {
        case .running: .green
        case .stopped: .secondary
        case .failed: .red
        case .stale: .orange
        }
    }
}
