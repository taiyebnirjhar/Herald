# Decisions

Each entry: date, decision, reason. Plan-level decisions D1–D7 are in PLAN.md §3.

## 2026-11-13 — Phase 0 foundation

- **Flutter pinned to 3.47.9 (stable).** Two weeks old at build time; CI uses the same version.
  Bump it deliberately, not by accident.
- **Android package id `com.taiyebnirjhar.herald`**, app name "Herald" (PLAN.md header).
- **`targetSdkVersion 28`, `minSdkVersion 29`, `arm64-v8a` only** (PLAN.md D2). The CI build
  checks these values from the built APK and fails if they change. Do not raise targetSdk
  without a new decision: targetSdk 29+ blocks running proot.
- **Release builds fail without the signing key.** A debug key differs on every CI runner,
  so updates would not install over the top. Failing loudly is safer than a silent debug build.
- **Signing key lives only in GitHub Actions secrets** (PLAN.md 0.3). The key file and
  passwords are never committed.
- **Release version:** the tag `vX.Y.Z` sets the version name; the GitHub run number sets the
  build number, so each new build has a higher number and can update the old one.
- **UI direction (owner's reference screens):** light, glassy, lavender-to-lime gradient,
  white rounded cards, bold sans headline, purple accent, floating bottom bar. Touch targets
  at least 44 px. Dark mode and themes come later (PLAN.md 5.6).
- **Licence: custom Herald licence** (owner decision). Free to use for any purpose. Credit must be kept and
  Herald never presented as someone else's work. Contributions by pull request, under the same terms.
  No resale of Herald or of modified versions. Changes are shared only as a pull request to the original repo.
  Source-available, not OSI open source. PolyForm was dropped because it cannot be changed to add these terms.

## In-app update (WBS 11.3)

- **Source of the newest version: the GitHub release page** (`/releases/latest`), read from its redirect.
  The GitHub API was tried first and hit its anonymous limit (60 requests an hour per network address), so
  phones on shared networks got a 403. The release page isn't limited that way.
- **Each release ships `herald-<version>-arm64.apk.sha256`** next to its APK. The app downloads the
  checksum file first, then the APK, and deletes the APK if its SHA-256 doesn't match. Android's own
  signature check (the same release key on every build) is the final guard.
- **A release without a checksum file is refused** before anything is downloaded.
- **Comparison:** `major.minor.patch` of the tag against the installed version name. CI sets the version
  name from the tag, so the two stay in step.
- **Install:** Android's installer, through a FileProvider limited to the app cache folder `updates/`.
  The first time, Android asks the player to allow installs from Herald; the card explains this.
- **Not shown yet:** release notes. The release page has them, but reading them needs a second page
  request; add later if wanted.
- **Limit (for now):** the download runs while the app is open. A download in the background
  (a foreground service, as in the arcade app) is a later step.
- **Limit (for now):** an interrupted download starts again from the beginning.
- Versions before 0.1.3 (0.1.1 and 0.1.2) still use the API and cannot finish an update.
  Install 0.1.3 once from the Releases page; after that the app updates itself.
- `targetSdk` stays 28 (see above). The arm64-only build is checked in CI.

## Linux runtime pieces: proot (WBS 1.1 and 1.2)

- **proot comes from the Termux packages** (`runtime/proot/README.md`), patched to load its neighbours from
  the app's native library folder (`$ORIGIN`). The patches are reproducible with `tools/patch-proot.sh`, which
  checks each package's SHA-256 first.
- **Native library folder, not app data:** the four files are packaged as native libraries and extracted
  (`useLegacyPackaging`). That folder is where Android lets an app run its own binaries, which is what
  targetSdk 28 relies on (PLAN.md D2).
- **Not yet proven on a phone.** Phase 1.2 is the phone test: the debug screen runs `proot --version`.
  Under qemu there is no Android linker, so nothing was run here.

