import AppKit
import IOKit.ps
import IOKit.pwr_mgt
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
	private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
	private let menu = NSMenu()
	private var assertionID: IOPMAssertionID = 0
	private var assertionAllowsDisplaySleep = false
	private var timer: Timer?
	private var endDate: Date?
	private var activeDuration: WakeDuration?
	private var settingsWindow: NSWindow?
	private var isOnBattery = false

	private var isActive: Bool { assertionID != 0 }

	func applicationDidFinishLaunching(_ notification: Notification) {
		Settings.registerDefaults()
		menu.delegate = self

		if let button = statusItem.button {
			button.target = self
			button.action = #selector(statusItemClicked)
			button.sendAction(on: [.leftMouseUp, .rightMouseUp])
		}

		enableLaunchAtLoginOnFirstRun()
		startMonitoringPowerSource()

		NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: UserDefaults.didChangeNotification, object: nil)

		if Settings.activateAtLaunch {
			activate(Settings.quickDuration)
		}
		updateIcon()
	}

	func applicationWillTerminate(_ notification: Notification) {
		deactivate()
	}

	// Launch at login is on by default; afterwards the user's choice is respected.
	private func enableLaunchAtLoginOnFirstRun() {
		guard !UserDefaults.standard.bool(forKey: Settings.Key.didSetUpLaunchAtLogin) else {
			return
		}
		try? SMAppService.mainApp.register()
		UserDefaults.standard.set(true, forKey: Settings.Key.didSetUpLaunchAtLogin)
	}

	// MARK: - Status item

	@objc private func statusItemClicked() {
		let event = NSApp.currentEvent
		let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
		let togglesDirectly = isRightClick == (Settings.toggleClick == .right)

		if togglesDirectly {
			isActive ? deactivate() : activate(Settings.quickDuration)
		} else {
			// Attach the menu only while it is shown so the toggle click keeps working.
			statusItem.menu = menu
			statusItem.button?.performClick(nil)
		}
	}

	func menuDidClose(_ menu: NSMenu) {
		statusItem.menu = nil
	}

	// Rebuild the menu each time it opens so the status and checkmarks are current.
	func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()

		let status: String
		if !isActive {
			status = NSLocalizedString("Inactive", comment: "")
		} else if let endDate {
			status = String(format: NSLocalizedString("Active until %@", comment: ""), endDate.formatted(date: .omitted, time: .shortened))
		} else {
			status = NSLocalizedString("Active indefinitely", comment: "")
		}
		menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))

		if isActive {
			menu.addItem(item(NSLocalizedString("Deactivate", comment: ""), #selector(deactivateAction)))
		}
		menu.addItem(.separator())

		menu.addItem(NSMenuItem.sectionHeader(title: NSLocalizedString("Stay Awake For", comment: "")))
		for duration in WakeDuration.allCases {
			let durationItem = item(duration.title, #selector(activateAction(_:)))
			durationItem.tag = duration.rawValue
			durationItem.state = activeDuration == duration ? .on : .off
			menu.addItem(durationItem)
		}
		menu.addItem(.separator())

		menu.addItem(item(NSLocalizedString("Settings…", comment: ""), #selector(showSettings), keyEquivalent: ","))
		menu.addItem(NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
	}

	private func item(_ title: String, _ action: Selector, keyEquivalent: String = "") -> NSMenuItem {
		let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
		item.target = self
		return item
	}

	@objc private func activateAction(_ sender: NSMenuItem) {
		if let duration = WakeDuration(rawValue: sender.tag) {
			activate(duration)
		}
	}

	@objc private func deactivateAction() {
		deactivate()
	}

	private func updateIcon() {
		let name = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
		let image = NSImage(systemSymbolName: name, accessibilityDescription: "WakeOver")
		image?.isTemplate = true
		statusItem.button?.image = image
		statusItem.button?.appearsDisabled = !isActive && Settings.dimIconWhenInactive
		statusItem.button?.toolTip = isActive ? NSLocalizedString("WakeOver: active", comment: "") : NSLocalizedString("WakeOver: inactive", comment: "")
	}

	// MARK: - Settings

	@objc private func showSettings() {
		if settingsWindow == nil {
			let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
			window.title = NSLocalizedString("WakeOver Settings", comment: "")
			window.styleMask = [.titled, .closable]
			window.isReleasedWhenClosed = false
			window.center()
			settingsWindow = window
		}
		NSApp.activate()
		settingsWindow?.makeKeyAndOrderFront(nil)
	}

	@objc private func settingsDidChange() {
		// Swap the assertion type in place when the display setting changes mid-session.
		if isActive, assertionAllowsDisplaySleep != Settings.allowDisplaySleep {
			releaseAssertion()
			createAssertion()
		}
		updateIcon()
	}

	// MARK: - Power assertion

	private func activate(_ duration: WakeDuration) {
		deactivate()
		createAssertion()
		guard isActive else {
			updateIcon()
			return
		}

		activeDuration = duration
		if let seconds = duration.seconds {
			endDate = Date(timeIntervalSinceNow: seconds)
			timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
				self?.deactivate()
			}
		}
		updateIcon()
	}

	private func deactivate() {
		timer?.invalidate()
		timer = nil
		endDate = nil
		activeDuration = nil
		releaseAssertion()
		updateIcon()
	}

	private func createAssertion() {
		let allowsDisplaySleep = Settings.allowDisplaySleep
		let type = allowsDisplaySleep ? kIOPMAssertionTypePreventUserIdleSystemSleep : kIOPMAssertionTypePreventUserIdleDisplaySleep
		let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "WakeOver" as CFString, &assertionID)
		if result == kIOReturnSuccess {
			assertionAllowsDisplaySleep = allowsDisplaySleep
		} else {
			assertionID = 0
		}
	}

	private func releaseAssertion() {
		if assertionID != 0 {
			IOPMAssertionRelease(assertionID)
			assertionID = 0
		}
	}

	// MARK: - Power source

	private func startMonitoringPowerSource() {
		isOnBattery = Self.isRunningOnBattery()
		let context = Unmanaged.passUnretained(self).toOpaque()
		guard let source = IOPSNotificationCreateRunLoopSource({ context in
			guard let context else {
				return
			}
			Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().powerSourceDidChange()
		}, context)?.takeRetainedValue() else {
			return
		}
		CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
	}

	private func powerSourceDidChange() {
		let wasOnBattery = isOnBattery
		isOnBattery = Self.isRunningOnBattery()
		// Only react to the switch itself; plugging back in does not reactivate.
		if !wasOnBattery, isOnBattery, isActive, Settings.deactivateOnBattery {
			deactivate()
		}
	}

	private static func isRunningOnBattery() -> Bool {
		guard let type = IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() else {
			return false
		}
		return (type as String) == kIOPMBatteryPowerKey
	}
}
