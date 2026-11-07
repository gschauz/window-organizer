# Cloud development workflow

The preferred workflow is GitHub-backed cloud development. Keep source changes in a cloud workspace on a feature branch and open a pull request. Do not create a new source checkout on the user's Mac unless requested. The installed app is independent of the source folder.

This is a native macOS app using SwiftUI, AppKit, Accessibility, and an Objective-C Spaces bridge. Build and test on macOS with Swift 6 or later. A Linux coding environment can edit the source but cannot validate these Apple frameworks; do not claim a successful build there. There are no third-party package dependencies.

Use the Mac build GitHub Actions workflow for automated tests and a downloadable app ZIP. Inspect the run for the current commit and resolve failures before declaring validation complete. Never run scripts/update.sh in CI or a cloud coding environment: it is only for an explicitly requested local Mac installation and can change Accessibility approval. Cloud builds use scripts/test.sh and scripts/build.sh with temporary output paths.

Downloads from Actions are temporary test builds, retained for 30 days. Keep approved versions as GitHub Release assets. Builds are Apple Silicon, ad-hoc signed, and not notarized; physical display, Spaces, and Accessibility testing still requires the user's Mac. Do not upload saved layouts, personal window titles, document paths, credentials, or screenshots to the public repository.

The local instructions below apply only when local development or installation is explicitly requested. Cloud setup, documentation, and workflow changes do not require rebuilding or relaunching the user's installed app.

# Local update workflow


For every user-facing update, including app icon changes, run `scripts/update.sh` with `WINDOW_ORGANIZER_BUILD_DIR` set to the workspace's `work/swift-build` directory. It builds and signs the app, relaunches it, refreshes its icon registration, checks Accessibility from the running GUI app, and refreshes only this app's stale approval when necessary.


Exit code 2 means macOS approval is still pending, not that the update is complete. Help the user enable Window Organizer in Accessibility settings; the user must perform any macOS authentication directly. Run `scripts/update.sh --verify-only` after approval and verify the banner has disappeared before reporting completion. Do not rebuild or re-sign again after approval. Do not reset other apps' permissions.


Keep `Window Organizer.zip` synchronized with the final signed bundle. `scripts/build.sh` alone is for build checks and does not finish a local user-facing update. Preserve saved layouts throughout this workflow.


Once installed, the everyday app lives at `/Applications/Window Organizer.app`. The update script detects and updates that installed copy in place. Do not launch or recreate a separate development app for everyday use. `WINDOW_ORGANIZER_APP_PATH` can explicitly choose a different build/install target. The ZIP in outputs remains the portable app artifact.

