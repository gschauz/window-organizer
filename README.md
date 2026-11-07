# Window Organizer

A native, local-only macOS menu-bar app for saving and restoring the layout of already-open windows. Built with SwiftUI, the macOS Accessibility APIs, and an isolated experimental Spaces bridge. No third-party dependencies.

## First use

1. Move **Window Organizer.app** into **Applications**, then open it from there. The installed app is self-contained; the source and build folders are only needed for development.
2. Click **Enable Accessibility** and enable **Window Organizer** in System Settings → Privacy & Security → Accessibility. The dashboard detects permission automatically. If macOS does not list the app, use the **+** button in that settings pane to add it.
3. Connect your monitors, arrange your normal app windows, click **New Layout**, name it **Desk**, and click **Save layout**.
4. Enable **Auto Apply Layout** on the Desk layout.
5. Disconnect your monitors, arrange the laptop windows, save **Laptop**, and enable **Auto Apply Layout** on that layout.
6. Open **File → Settings** and turn on **Switch layouts when displays change**. The app waits for display changes to settle, then applies the assigned layout. If you sometimes work with the lid closed, save a separate layout for those displays.

Click **Restore layout** or choose a layout from the menu-bar icon any time. **Undo Last Layout Change** in the menu-bar dropdown restores the layout captured immediately before the last restore. Closing the dashboard keeps the menu-bar app running. **Open at login** is optional.

## What this version handles

- Named layouts with per-monitor desktop previews, selectable desktop thumbnails, and an included-window list.
- Desktop counts and per-window desktop assignments. Saving briefly visits inactive desktops to read their windows, then returns to the starting desktops.
- Missing ordinary desktops are created through Mission Control; surplus desktops are preserved. Saved desktop UUIDs are matched first, with per-monitor order used after recreation. Desktop moves are verified.
- Save, restore, update, rename, and delete layouts.
- Monitor identity, relative placement, usable screen bounds, negative monitor coordinates, and resolution changes.
- An optional layout per connected display configuration, applied after connection changes or wake.
- Best-effort window matching by application, document, and title. An app with one saved and one available window can match even when its title changes. Ambiguous windows are skipped and reported.
- Position verification and a retry when an application does not immediately accept a move.
- Missing monitors fall back to the primary display for manual restores.
- A details report for skipped or constrained windows.

## Limits

Desktop support is experimental and uses undocumented macOS APIs that can change with an OS update. If a desktop cannot be read, saving leaves the previous layout intact. Failed moves and missing desktops are reported. Extra desktops are never deleted automatically; Undo restores window geometry and desktop assignments but does not remove desktops that were created. Windows assigned to multiple desktops keep their existing assignment.

The app does not reopen apps, documents, or browser tabs. Full-screen and minimized windows are skipped. Other apps may enforce minimum window sizes or expose incomplete Accessibility information. Identical window titles may need to be made distinct to match reliably. Undo is in memory and does not survive quitting.

Automatic matching uses the connected monitors' UUIDs. A dock or adapter that changes a monitor's identity may require updating the layout. Mirrored displays and hot-unplugging while a restore is in progress need manual checking. The app must remain running for automatic switching.

## Data and permissions

The app stores layouts in `~/Library/Application Support/WindowOrganizer/presets.json`. This includes window titles and, when apps provide them, document paths. It does not store screenshots or document content and makes no network requests. Use **File → Settings → Open layout data folder** to open the data folder. Back up this JSON file to preserve layouts.

Accessibility access is required to inspect and move other applications' windows. The app only requests access when you click **Enable Accessibility**. Screen Recording permission is not required.

The supplied app is built for Apple Silicon and signed locally (ad hoc), not notarized for public distribution. Rebuilding or moving the app can require reauthorizing Accessibility. For shipping to other users, add Developer ID signing and notarization.

## Build and test

Requires macOS 13 or later and Swift 6+ (Xcode or Command Line Tools).

```sh
bash scripts/build.sh
bash scripts/test.sh
```

The build script creates `../Window Organizer.app` and verifies its local code signature. `WINDOW_ORGANIZER_BUILD_DIR` optionally selects the build/cache directory.

For local user-facing updates, run `bash scripts/update.sh`. It updates `/Applications/Window Organizer.app` in place when installed; otherwise it uses the app beside this source folder. `WINDOW_ORGANIZER_APP_PATH` explicitly overrides that destination. It quits the previous app, builds and relaunches the new one, refreshes macOS icon registration, and checks Accessibility from the running GUI app. If access is missing, it resets only Window Organizer’s approval and opens Accessibility settings. macOS may still require the user to enable the app and authenticate; the updater cannot grant that approval itself. Exit code 2 means approval is pending. After approval, run `bash scripts/update.sh --verify-only` to verify access without another build or permission reset. Unchanged permissions are preserved when the new app already has access.

## Manual acceptance check

1. Open two distinct normal windows and save a layout.
2. Move and resize them, then restore; inspect the result and any details.
3. Use Undo and confirm the pre-restore layout returns.
4. Quit and reopen the organizer and confirm the layout persists.
5. Save and assign both Desk and Laptop, enable automatic switching, and physically connect/disconnect the monitors.
6. Verify closed windows and ambiguous duplicates are reported without launching new windows.
7. Confirm full-screen and minimized windows are left alone.
8. Save windows spread across ordinary desktops, move one to another desktop, restore, and verify desktop membership as well as geometry.
9. Add a missing desktop through Restore and verify its monitor and order. Verify surplus desktops are retained.
10. Click desktop thumbnails and confirm only the preview changes.

Automated tests cover display geometry, scaling and clamping, window matching, and preference serialization. Actual cross-app movement and dock/undock behavior require Accessibility permission and testing on the user's physical displays.
