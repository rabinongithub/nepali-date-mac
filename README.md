# Nepali Date — macOS menu-bar app

## Get a built app without installing Xcode or Swift

This project includes a GitHub Actions workflow that compiles an Apple Silicon `.app` on a hosted macOS runner. You do not need to install Xcode or Swift on your own Mac to use the build artifact.

### One-time build steps

1. Sign in to GitHub and create a **private** repository (for example, `nepali-date-mac`).
2. Upload the contents of this folder to that repository, preserving the `.github/workflows/build.yml` path.
3. Open the repository's **Actions** tab. If prompted, enable Actions.
4. Choose **Build Nepali Date for Mac**, click **Run workflow**, and run it on the default branch.
5. When the workflow finishes successfully, open that run and download the `Nepali-Date-Apple-Silicon` artifact.
6. Double-click the downloaded ZIP to extract `Nepali Date.app`, then drag it into `/Applications`.
7. On first launch, macOS may block the app because it is not signed/notarized with an Apple Developer ID. If you trust the source, Control-click the app in Finder and choose **Open**, then confirm. The exact prompt depends on your macOS security settings.
8. Open the app. The Nepali date appears in the menu bar. Click it to see the calendar and enable **Launch at login**.

### Important signing limitation

This workflow creates an Apple Silicon app bundle and applies an ad-hoc signature. It does **not** create an Apple-notarized public distribution. For the same smooth first-open experience as apps downloaded from established developers, the app needs a Developer ID Application certificate and Apple notarization; those require an Apple Developer account and credentials. Never add signing credentials to a public repository or commit them into source files.

## App features

- Menu bar displays the Bikram Sambat date using English digits.
- Click the date to open the BS month grid, Gregorian date, and live Nepal time (Asia/Kathmandu, UTC+05:45).
- Local calendar conversion and clock; no network requests in the app.
- Launch at login toggle.
- Requires macOS 13 or newer; built for Apple Silicon (`arm64`).

## Offline calendar coverage

The bundled data currently covers BS 2080–2090 (approximately AD 2023–2034). Dates outside this range display as unavailable. This is not yet a full-range official calendar, so verify important dates against an authoritative Nepali Patro.

## Local build (optional)

If you already have Swift installed, run `./build-mac-app.sh` from this folder.
