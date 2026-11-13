# Herald

Herald is a one-tap Android app that runs the open-source **Hermes Agent** on your phone.
No Termux, no terminal, no commands.

Status: **Phase 0 (Hello app)**. The app opens and shows a Hello screen. Hermes is not
installed yet (that is Phase 1 onward). The plan is in [PLAN.md](PLAN.md); the rules for
the build are in [CLAUDE.md](CLAUDE.md).

## Install Herald on your phone (Samsung Galaxy M14, or any arm64 Android 10+ phone)

You install from GitHub Releases. You do not need a computer.

1. **Turn off Auto Blocker** (Samsung): Settings → Security and privacy → Auto Blocker → off.
   Samsung blocks installing apps from outside the Play Store while it is on.
2. Open the **Releases** page of this repo on your phone's browser:
   `https://github.com/taiyebnirjhar/Herald/releases`
3. Tap the newest release, then tap the file named `herald-<version>-arm64.apk`.
4. When Android asks, allow your browser to **install unknown apps** (one time only).
5. Tap **Install**, then **Open**.

To update later, repeat steps 2–5. The new version installs over the old one and keeps your data.

## Repo layout

| Folder | What is in it |
| --- | --- |
| `app/` | The Flutter app (`lib/`, `test/`) |
| `app/android/` | Android platform code (Gradle, Kotlin, manifest) |
| `runtime/` | Hermes pin and runtime build config (Phase 1 onward) |
| `tools/` | Build and helper scripts |
| `docs/` | Decisions, security notes, test matrix, upgrade playbook |
| `.github/workflows/` | CI: `app.yml` builds the APK and publishes releases |

## Build and release (for the maintainer)

- Every push to `main` or a `feat/`, `fix/`, `chore/` or `docs/` branch runs analyze, tests and a release build in
  GitHub Actions. The APK is in the run's **Artifacts**.
- To publish a release: on GitHub open **Actions → App (APK) → Run workflow**, choose the branch, type the tag
  (for example `v0.1.0`) in **release_tag**, and run it. The workflow creates the tag and the GitHub Release with the signed APK.
- Pushing a tag like `v0.1.0` also publishes a release.

## Signing key (one-time setup, required for any release)

Every release is signed with one private key. Android only lets an app update itself if
the key matches. **Keep the key and its passwords safe. If they are lost, phones cannot
update to new versions.** Never commit the key file to the repo.

The key is stored as four GitHub Actions secrets:

| Secret name | What to put in it |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The key file, converted to text (base64) |
| `ANDROID_KEYSTORE_PASSWORD` | The key store password |
| `ANDROID_KEY_ALIAS` | The key alias (for example `herald`) |
| `ANDROID_KEY_PASSWORD` | The key password |

To add them on GitHub (phone or computer):

1. Open the repo on GitHub → **Settings** → **Secrets and variables** → **Actions**.
2. Tap **New repository secret**, enter the name from the table, paste the value, tap **Add secret**.
3. Repeat for all four secrets.
4. Re-run the failed **App (APK)** workflow under **Actions**.

If a secret is missing, the build stops with a clear message and does not produce an APK.

## Licence

Herald is free to use, and free to contribute to. The full terms are in [LICENSE](LICENSE). In short:

- Use it free of charge for any purpose.
- Keep the credit to Herald and its author. Never present it as your own.
- Improvements go back as a **pull request** to this repository.
- Nobody may sell Herald, or sell a modified version of it.

Third-party components keep their own licences, listed in [THIRD_PARTY.md](THIRD_PARTY.md).
