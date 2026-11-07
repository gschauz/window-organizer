# Local update workflow

For every user-facing update, including app icon changes, run `scripts/update.sh` with `WINDOW_ORGANIZER_BUILD_DIR` set to the workspace's `work/swift-build` directory. It builds and signs the app, relaunches it, refreshes its icon registration, checks Accessibility from the running GUI app, and refreshes only this app's stale approval when necessary.

Exit code 2 means macOS approval is still pending, not that the update is complete. Help the user enable Window Organizer in Accessibility settings; the user must perform any macOS authentication directly. Run `scripts/update.sh --verify-only` after approval and verify the banner has disappeared before reporting completion. Do not rebuild or re-sign again after approval. Do not reset other apps' permissions.

Keep `Window Organizer.zip` synchronized with the final signed bundle. `scripts/build.sh` alone is for build checks and does not finish a local user-facing update. Preserve saved layouts throughout this workflow.

Once installed, the everyday app lives at `/Applications/Window Organizer.app`. The update script detects and updates that installed copy in place. Do not launch or recreate a separate development app for everyday use. `WINDOW_ORGANIZER_APP_PATH` can explicitly choose a different build/install target. The ZIP in outputs remains the portable app artifact.
