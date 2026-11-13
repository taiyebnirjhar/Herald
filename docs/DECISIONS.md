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
- **Licence (open):** `LICENSE` is a placeholder "all rights reserved" text until the owner
  chooses a licence. Owner decision needed.
