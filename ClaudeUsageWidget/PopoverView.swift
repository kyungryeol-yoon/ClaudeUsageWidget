import SwiftUI

private let kBg = Color(red: 0.11, green: 0.21, blue: 0.42)

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings = AppSettings.shared
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsPanel(settings: settings)
                    .padding(16)
            } else {
                mainContent
            }

            rowDivider
            bottomBar
        }
        .frame(width: 300)
        .background(kBg)
        .foregroundStyle(.white)
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if let usage = viewModel.usage {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("CURRENT SESSION")
                usageRow(label: "5-hour limit",
                         value: usage.fiveHour,
                         resetAt: usage.fiveHourResetsAt)

                rowDivider

                sectionHeader("WEEKLY LIMITS")
                usageRow(label: "All models",
                         value: usage.weekly,
                         resetAt: usage.weeklyResetsAt)

                thinDivider
            }
        } else if let error = viewModel.lastError {
            Text(error)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(16)
        } else {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Loading…")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)

            if viewModel.isLoading {
                ProgressView().scaleEffect(0.6).tint(.white)
            }

            Spacer()

            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .disabled(viewModel.isLoading)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Reusable subviews

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
            .tracking(0.4)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func usageRow(label: LocalizedStringKey, value: Double?, resetAt: Date?) -> some View {
        let pct   = value.map { Int($0 * 100) } ?? 0
        let color = barColor(value ?? 0)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
            }

            UsageBar(value: value ?? 0, color: color)
                .frame(height: 7)

            Text(ResetTimeFormatter.resetLine(resetAt))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func barColor(_ value: Double) -> Color {
        switch value {
        case ..<0.6:  return .green
        case ..<0.85: return .orange
        default:      return .red
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - UsageBar

struct UsageBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(Color.white.opacity(0.14))
                if value > 0 {
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(color)
                        .frame(width: geo.size.width * min(value, 1))
                        .animation(.easeOut(duration: 0.4), value: value)
                }
            }
        }
    }
}

// MARK: - SettingsPanel (dark-themed)

struct SettingsPanel: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingRow(label: "Menu bar icon") {
                Picker("", selection: $settings.menuBarIcon) {
                    ForEach(MenuBarIcon.allCases) { icon in
                        Text(icon.label).tag(icon)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            settingRow(label: "Menu bar display") {
                Picker("", selection: $settings.displayStyle) {
                    ForEach(DisplayStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(settings.menuBarIcon != .none)

                if settings.menuBarIcon != .none {
                    Text("Icon mode locks the style to text only.")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.top, -2)
                }
            }

            settingRow(label: "Refresh interval") {
                Picker("", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Toggle("Show remaining time in menu bar", isOn: $settings.showTimer)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .padding(.top, 4)

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 4)

            Toggle("Notifications", isOn: $settings.notificationsEnabled)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            Toggle("Threshold alerts at 60, 85, 95", isOn: $settings.thresholdAlertsEnabled)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .disabled(!settings.notificationsEnabled)

            Toggle("Reset reminder", isOn: $settings.resetReminderEnabled)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .disabled(!settings.notificationsEnabled)

            settingRow(label: "Reminder lead time") {
                Picker("", selection: Binding(
                    get: { ResetReminderLead(rawValue: settings.resetReminderMinutes) ?? .tenMin },
                    set: { settings.resetReminderMinutes = $0.rawValue }
                )) {
                    ForEach(ResetReminderLead.allCases) { lead in
                        Text(lead.label).tag(lead)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!settings.notificationsEnabled || !settings.resetReminderEnabled)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func settingRow<Content: View>(label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            content()
        }
    }
}
