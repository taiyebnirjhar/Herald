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

- **Source of truth: the GitHub Releases API** (`releases/latest`). No separate version file to host.
  A release counts only if it has an `.apk` asset served from `https://github.com/` with a SHA-256
  digest. Releases without those are ignored.
- **Integrity:** the downloaded APK must match the SHA-256 GitHub publishes for it, and the byte count
  must match. A file that fails is deleted and never installed. Android's own signature check
  (same release key on every build) is the final guard.
- **Comparison:** `major.minor.patch` of the tag against the installed version name. CI sets the version
  name from the tag, so the two stay in step.
- **Install:** Android's installer, through a FileProvider limited to the app cache folder `updates/`.
  The first time, Android asks the player to allow installs from Herald; the card explains this.
- **Limit (for now):** the download runs while the app is open. A download in the background
  (a foreground service, as in the arcade app) is a later step.
- **Limit (for now):** an interrupted download starts again from the beginning.
- The version you install before this update exists (0.1.0) cannot update itself; install 0.1.1 from
  the Releases page once.
- `targetSdk` stays 28 (see above). The arm64-only build is checked in CI.

