import SwiftUI

@main
struct ClaudeUsageWidgetApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(usage: viewModel.usage, now: viewModel.clockTick)
        }
        .menuBarExtraStyle(.window)
    }
}
