# Build the APK on GitHub

The workflow in `.github/workflows/android.yml` uses GitHub's Ubuntu runner to
install Godot 4.6.3 and Android dependencies, run the game tests, export the APK,
verify its signature/package/native libraries and upload a downloadable artifact.
Godot binary/template downloads have SHA-256 checks from the official release.

The workflow requires no custom secrets for its development debug build. It uses
read-only repository permissions and does not publish the game to a store.

## Repository setup

Put this project's contents at the repository root so `project.godot`, `android/`
and `.github/` are siblings. GitHub only finds workflows under the repository's
root `.github/workflows` directory.

Pushing code to `main`, `master` or an `ironfall/` branch triggers the build.
Pull requests also run it. For a manual build, open **Actions → Build Android APK
→ Run workflow** after the workflow is on the default branch.

## Download

Open a successful run's **Artifacts → ironfall-debug-apk**, download and unzip it.
The ZIP contains `ironfall-debug.apk` and its SHA-256 checksum. Build/test logs are
uploaded separately, even when a build fails.

This is a debug-signed phone-testing APK. The temporary runner creates a debug
key each run; updating an installed APK from another run may require uninstalling
it first. Use a persistent private signing key for repeatable release builds.

The workflow has successfully exported and verified APKs. Its separate API 35
emulator job exercises real touch navigation, mission launch, pause/resume,
background/foreground events and save/relaunch, and uploads screenshots/logs as
`ironfall-android-smoke`. Both jobs passed for human build 0.2.1 in
[run 37074024404](https://github.com/umardevexpert/Shooting-game/actions/runs/37074024404). Physical-device
performance, human playtesting and final visual quality remain release checks.
