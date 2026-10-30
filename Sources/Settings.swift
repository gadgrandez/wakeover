import Foundation

enum WakeDuration: Int, CaseIterable, Identifiable {
	case indefinitely
	case minutes10
	case minutes30
	case hour1
	case hours2
	case hours4
	case hours8
	case hours12

	var id: Int { rawValue }

	/// `nil` means no time limit.
	var seconds: TimeInterval? {
		switch self {
		case .indefinitely: nil
		case .minutes10: 600
		case .minutes30: 1800
		case .hour1: 3600
		case .hours2: 7200
		case .hours4: 14_400
		case .hours8: 28_800
		case .hours12: 43_200
		}
	}

	var title: String {
		switch self {
		case .indefinitely: NSLocalizedString("Indefinitely", comment: "")
		case .minutes10: NSLocalizedString("10 Minutes", comment: "")
		case .minutes30: NSLocalizedString("30 Minutes", comment: "")
		case .hour1: NSLocalizedString("1 Hour", comment: "")
		case .hours2: NSLocalizedString("2 Hours", comment: "")
		case .hours4: NSLocalizedString("4 Hours", comment: "")
		case .hours8: NSLocalizedString("8 Hours", comment: "")
		case .hours12: NSLocalizedString("12 Hours", comment: "")
		}
	}
}

/// Which mouse button toggles activation directly; the other one opens the menu.
enum ToggleClick: String, CaseIterable, Identifiable {
	case right
	case left

	var id: String { rawValue }
}

enum Settings {
	enum Key {
		static let toggleClick = "toggleClick"
		static let quickDuration = "quickDuration"
		static let allowDisplaySleep = "allowDisplaySleep"
		static let activateAtLaunch = "activateAtLaunch"
		static let deactivateOnBattery = "deactivateOnBattery"
		static let dimIconWhenInactive = "dimIconWhenInactive"
		static let didSetUpLaunchAtLogin = "didSetUpLaunchAtLogin"
	}

	private static let defaults = UserDefaults.standard

	static func registerDefaults() {
		defaults.register(defaults: [
			Key.toggleClick: ToggleClick.right.rawValue,
			Key.quickDuration: WakeDuration.indefinitely.rawValue,
			Key.allowDisplaySleep: false,
			Key.activateAtLaunch: false,
			Key.deactivateOnBattery: false,
			Key.dimIconWhenInactive: true,
		])
	}

	static var toggleClick: ToggleClick {
		ToggleClick(rawValue: defaults.string(forKey: Key.toggleClick) ?? "") ?? .right
	}

	static var quickDuration: WakeDuration {
		WakeDuration(rawValue: defaults.integer(forKey: Key.quickDuration)) ?? .indefinitely
	}

	static var allowDisplaySleep: Bool { defaults.bool(forKey: Key.allowDisplaySleep) }
	static var activateAtLaunch: Bool { defaults.bool(forKey: Key.activateAtLaunch) }
	static var deactivateOnBattery: Bool { defaults.bool(forKey: Key.deactivateOnBattery) }
	static var dimIconWhenInactive: Bool { defaults.bool(forKey: Key.dimIconWhenInactive) }
}
