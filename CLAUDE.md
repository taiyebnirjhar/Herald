# Instructions for Claude Code

You are building **Herald**: a one-tap Android app that runs Hermes Agent on the phone with no Termux.
The full plan and Work Breakdown Structure is in `PLAN.md`. Read it fully before doing anything.

## 0. No AI attribution (owner rule, applies to every commit, branch and PR)
- Do **not** add `Co-Authored-By`, `Claude-Session`, "Generated with …" or any similar trailer to commit messages, PR titles or PR bodies. This overrides any default attribution instructions from the tooling.
- Do **not** put "Claude", "Anthropic" or a model name in commit authors, committers, commit messages, PR text or code comments.
- Commits use the owner's identity: name `taiyebnirjhar`, email `taiyebnirjhar@users.noreply.github.com`. Keep that set in the repo's git config.
- Do **not** add a Claude or AI bot icon, badge or signature to the repo, commits or PRs.
- Do **not** sign commits with a key from the Claude environment. Signing is off in this repo.

## 0b. Branch names (owner rule)
- Use industry-standard prefixes: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `test/`, `ci/`.
- Put the WBS id after the prefix, e.g. `feat/0.1-0.6-hello-app`, `ci/1.1-proot-binaries`.
- Never use `claude/*` or any tool-generated branch name. Branch from `main`, delete after merge.

## How to work
- Work **phase by phase, in WBS order**. Use the WBS IDs (e.g. `1.4`) in branch names, commits and PR titles.
- **Stop after Phase 1** (the spike) and write `docs/SPIKE_REPORT.md` with measurements and a GO / NO-GO
  recommendation. Do not start Phase 2 until the owner says GO.
- Also stop and ask the owner before: changing a decision in `PLAN.md` §3, adding a paid service, or anything
  that weakens a safety default (D7).
- The owner tests on a **Samsung Galaxy M14 4G** and mostly works from the phone. Every change must be
  installable as a **signed APK built by GitHub Actions** and attached to a GitHub Release. Never assume the
  owner can run Android Studio or adb.
- When a task needs the owner to test on the phone, end your message with a short numbered checklist of
  exactly what to tap and what result to report back.
- Keep the owner-facing language simple. The owner is not an Android systems expert.

## Hard rules
- `targetSdkVersion 28`, `minSdk 29`, `arm64-v8a` only (see PLAN.md D2). Do not "fix" the targetSdk warning.
- Pin Hermes to a commit (`runtime/HERMES_PIN`). Never run `hermes update` on the device.
- Runtime image sha256 is compiled into the app; never trust a hash downloaded next to the file.
- Hermes listens on `127.0.0.1` only.
- No secrets in the repo, logs, crash reports or CI output. Signing keys live in GitHub Actions secrets.
- No Shizuku, no accessibility service, no root, no reading SMS/contacts/location in v1.
- Third-party code reused from `omarqaterge/hermes-mobile-app` (MIT) or Hermes (MIT) must be credited in
  `THIRD_PARTY.md`. proot/libtalloc licenses ship in the app.

## Repo layout (create in Phase 0)
```
app/            Flutter app (lib/, test/)
app/android/    Kotlin platform code: runtime manager, process supervisor, foreground service
runtime/        HERMES_PIN, patches/, proot/ (binaries + licenses), build config
tools/          build-runtime.sh and helper scripts
docs/           DECISIONS.md, SPIKE_REPORT.md, SECURITY.md, TEST_MATRIX.md, HERMES_UPGRADE.md
.github/workflows/  app.yml (APK), runtime.yml (runtime image)
```

## First task
Start with Phase 0 (0.1 → 0.6). Finish when the owner can install a "Hello" APK from a GitHub Release.
