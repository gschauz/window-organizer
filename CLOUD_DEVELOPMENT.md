# Working on Window Organizer in the cloud

GitHub holds the source and its history. Cloud tasks use a remote working copy. Your Mac only needs the installed app and any test builds you choose to download; the app does not depend on a source folder.

## One-time cloud environment setup

In ChatGPT, choose **Work in > Cloud > Select environment > Create environment**, select `gschauz/window-organizer`, and connect GitHub if prompted. Review the setup, then publish the environment. See the [official cloud setup guide](https://learn.chatgpt.com/docs/cloud).

Tell the setup agent that this is a native macOS SwiftUI app with no third-party package dependencies. A Linux workspace is suitable for editing but cannot build Apple frameworks. Use the **Mac build** GitHub Actions workflow for compilation and tests. Do not run `scripts/update.sh` in the cloud.

## Adding a feature later

1. Start a cloud task using this repository and describe the feature.
2. Make changes on a feature branch: a separate version of the code while work is in progress.
3. Open a pull request: a reviewable proposal to bring the changes into `main`.
4. Wait for **Mac build / Test and package app** to pass for the latest commit.
5. Download the app and test the feature on your Mac, including any affected monitor or desktop behavior.
6. Merge the tested pull request into `main`. Keep approved downloadable versions in GitHub Releases.

## Downloading a test build

Open the repository's **Actions** tab, choose a successful **Mac build** run for your branch or pull request, then download the app ZIP from **Artifacts**. These downloads expire after 30 days; a fresh run creates a new download. After this workflow is on `main`, you can also select **Mac build > Run workflow** to request a build manually.

Quit Window Organizer before replacing the app in Applications. Extract the ZIP and move **Window Organizer.app** into Applications. Saved layouts live separately in `~/Library/Application Support/WindowOrganizer/presets.json`; keep a backup before testing changes. Never commit that personal file to GitHub.

These builds target Apple Silicon, are ad-hoc signed, and are not notarized. macOS may require approval to open a downloaded build and may require Accessibility to be enabled again. Cloud tests cannot verify your actual monitors, Spaces, or Accessibility permissions.

## Durable downloads

GitHub Releases are on the same repository page. Attach the tested **Window Organizer.zip** as a release asset; the automatically generated source-code ZIP is not the application. Keep the release tied to the commit that produced the tested build. Publishing a release is a separate step from creating a test artifact.
