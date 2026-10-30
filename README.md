# WakeOver

A tiny macOS menu bar app that keeps your Mac awake.

- Right-click the cup icon to toggle keep-awake; left-click opens the menu (swappable in Settings).
- Pick a duration from the menu: indefinitely, 10 or 30 minutes, or 1–12 hours.
- Optionally let the display sleep while the computer stays awake.
- Activate at launch, deactivate when switching to battery, launch at login.
- Follows the system language (English and Spanish included).

Requires macOS 14 or later.

## Build

Only the Xcode Command Line Tools are needed:

```sh
./build.sh
ditto build/WakeOver.app /Applications/WakeOver.app
```
