# Quadro

A personal dashboard for macOS: calendar, reminders, weather, birthdays and unread mail in a single window.
It reads from and writes directly to Apple Calendar and Reminders.

## Requirements

- macOS 26 or later
- Swift 6.2 (the Command Line Tools are enough, Xcode is not required)

## Commands

```sh
scripts/create-signing-cert.sh   # once: local certificate used to sign the app
scripts/run.sh                   # build, bundle and launch the app
scripts/run.sh --mock            # launch with sample data
scripts/test.sh                  # tests
scripts/bundle.sh release        # build/Quadro.app
scripts/install.sh               # install or update /Applications/Quadro.app
swift scripts/make-icon.swift    # regenerate Resources/AppIcon.icns
.build/debug/Quadro --snapshot out.png [--view day|week|month] [--dark]   # render the window to a PNG with sample data
```

## Structure

- `Sources/DashboardCore`: models, logic, themes, service protocols, mocks. No system framework dependencies besides Foundation.
- `Sources/DashboardServices`: EventKit, CoreLocation, Open-Meteo, AppleScript for Mail.
- `Sources/Quadro`: SwiftUI app.

## Install and update

```sh
scripts/create-signing-cert.sh   # once
scripts/install.sh               # builds a release and copies it to /Applications
git pull && scripts/install.sh   # update
```

The app is signed with the local certificate, so macOS keeps the granted permissions across updates.
