import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
	@AppStorage(Settings.Key.toggleClick) private var toggleClick = ToggleClick.right
	@AppStorage(Settings.Key.quickDuration) private var quickDuration = WakeDuration.indefinitely
	@AppStorage(Settings.Key.allowDisplaySleep) private var allowDisplaySleep = false
	@AppStorage(Settings.Key.activateAtLaunch) private var activateAtLaunch = false
	@AppStorage(Settings.Key.deactivateOnBattery) private var deactivateOnBattery = false
	@AppStorage(Settings.Key.dimIconWhenInactive) private var dimIconWhenInactive = true
	@StateObject private var loginItem = LaunchAtLogin()

	var body: some View {
		Form {
			Section {
				Picker("Activate with", selection: $toggleClick) {
					Text("Right-click").tag(ToggleClick.right)
					Text("Left-click").tag(ToggleClick.left)
				}
				Picker("Duration", selection: $quickDuration) {
					ForEach(WakeDuration.allCases) { duration in
						Text(duration.title).tag(duration)
					}
				}
			} header: {
				Text("Quick Activation")
			} footer: {
				Text("The other click opens the menu.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("Behavior") {
				Toggle(isOn: $allowDisplaySleep) {
					Text("Allow Display to Sleep")
					Text("Keeps the computer awake but lets the display turn off.")
				}
				Toggle("Activate at launch", isOn: $activateAtLaunch)
				Toggle("Deactivate when switching to battery", isOn: $deactivateOnBattery)
			}

			Section("General") {
				Toggle("Launch at Login", isOn: $loginItem.isEnabled)
				Toggle("Dim icon while inactive", isOn: $dimIconWhenInactive)
			}
		}
		.formStyle(.grouped)
		.frame(width: 420)
		.fixedSize()
	}
}

/// Mirrors the login item status; the command line toolchain lacks the SwiftUI macro plugin needed by `@State`.
final class LaunchAtLogin: ObservableObject {
	var isEnabled: Bool {
		get { SMAppService.mainApp.status == .enabled }
		set {
			let service = SMAppService.mainApp
			do {
				if newValue {
					try service.register()
				} else {
					try service.unregister()
				}
			} catch {
				NSAlert(error: error).runModal()
			}
			objectWillChange.send()
		}
	}
}
