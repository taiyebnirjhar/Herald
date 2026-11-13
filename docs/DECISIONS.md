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

## Update size: image downloaded once, not in every APK (decided 2026-11-13)

- Release APKs are small (about 8 MB). The Linux base image (52 MB) is downloaded once, the first time the
  player installs it, and reused until the runtime version changes.
- The image's address and SHA-256 are compiled into the app (RuntimeImage.kt). The download is checked
  before it is unpacked.
- The earlier bundled approach (60 MB APKs) is dropped to keep updates small.


## Download progress gap: downloads inside the Linux base (rule 0d)

- Downloads the Hermes installer makes inside the Linux base (package installs, uv and Python) report
  progress from the installer's own stages (its log lines), not from bytes. The setup screen shows the
  latest stage line and the step.
- Byte-level progress for these is not built yet. Planned: parse the installer's progress lines, or run the
  package steps through a counted download. Owner to be told when this changes.

## Battery: keep Hermes running (WBS 4.6)

- The app asks Android to allow it to run in the background (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). Android
  shows its own question once; the app shows whether the answer is yes.
- Samsung's battery screen is tried first (`com.samsung.android.lool`). We have not confirmed this component on
  the Galaxy M14, so if it is missing the app falls back to Android's battery list, then Herald's app page.
  Owner to report which screen opens on the phone; the plain steps on the screen cover the rest.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is restricted on Google Play. Herald is installed from GitHub
  Releases, not Play, so this does not apply to v1.

## Job result notifications (WBS 0.3.4)

- A finished scheduled-job run is announced once. Herald reads `GET /api/jobs` (`include_disabled=true`)
  and looks at each job's `latest_execution` (Hermes `cron/jobs.py` `list_jobs`, `cron/executions.py`).
  A run is finished when its status is `completed`, `failed` or `unknown`.
- Checks run every 60 seconds. While the app is open, the Dart side checks (`lib/notify/`). While the app is
  closed and Hermes runs, the Kotlin poller checks (`JobRunPoller.kt`). The app's screen decides which one.
- One saved value per job holds the last announced run id. Both sides read and write it in Herald's own
  SharedPreferences (`job_runs`), so a run is never announced twice. The Dart side reaches it through the
  `herald/notify` channel. (shared_preferences 2.5 keeps data in DataStore on Android, so the two sides do not
  share that store.)
- The first look at a job is silent, so installing the app does not announce old runs. A run still going at
  that first look is announced when it finishes.
- Hermes gives a job's name from its prompt when the job has no name. Herald replaces such a name with
  "Scheduled job", so no prompt text reaches a notification.
- Known gap: only the newest run of a job is visible. If one job finishes two runs between two checks, the
  earlier one is not announced. Jobs are normally spaced far enough apart that this does not happen.
- Known gap: "unknown" means Hermes lost track of the run (for example after a crash). It is announced as
  "ended unclearly", not as a failure.
- Android 13 and later: Herald targets SDK 28 (D2), so Android shows no permission question for notifications.
  The owner must turn notifications on for Herald in Android settings, or nothing is shown.
## Connection to Hermes's API: random port, key only when confirmed (security review)

- **Why:** the security review found that the app sent the Hermes key to whatever answered on a fixed port (8642). If Hermes was stopped, another app could answer there and receive the next message's key.
- **Random port per install:** the API server now listens on a port chosen once per install (20000 to 59999), stored with the key in the app's private folder.
- **Key only when confirmed:** the app gets the key only while the supervisor has seen Hermes answer on that port. Otherwise the key is empty, and the chat and jobs screens send nothing.
- **Chat re-reads the address before each message**, so a stopped Hermes never receives the key.
- **Remaining risk:** another app could still bind the random port in the short window after Hermes stops, before the supervisor notices. The window is short and the port is random. A stronger fix would need a socket only this app can reach, which Hermes's API server does not offer today.
- **Also fixed in the same change:** a provider key or model starting with a dash is refused (Hermes would read it as an option); a Hermes error during a reply is shown as an error instead of an empty bubble; the key store is synchronised so two threads cannot create two keys.
- **Not yet fixed:** keep the Hermes key out of the agent's own commands. This needs a patch to Hermes's scrub list under `runtime/patches/`.
