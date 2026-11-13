# Herald — Project Plan & Work Breakdown Structure

> App name: **Herald** · Repo: `taiyebnirjhar/Herald` · Android package id: `com.taiyebnirjhar.herald`.
> Do not use "Hermes" or "Hermux" in the app name or icon — those names belong to their owners.
> Owner: the repo owner. Builder: Claude Code. Status: Phase 0 not started.

---

## 1. Goal

A single Android app that runs the open-source **Hermes Agent** (Nous Research, MIT) fully on the phone.

**The user experience we are building:**

1. Download the APK, install it (Android asks "allow install?" once).
2. Open it. It downloads its built-in Linux + Hermes with a progress bar (one time, ~10–20 min).
3. One system popup: "Allow running in background?" → Allow.
4. Paste an API key (or sign in to a subscription). Start chatting.

**No Termux. No terminal. No Developer options. No commands.**

The agent's job (later phases): an SEO "employee" — keyword research, blog drafts, social posts, trend
tracking, publishing — plus personal tasks through a headless browser.

### Non-goals (for now)
- iOS (iOS cannot run a Linux environment this way).
- Google Play Store distribution (see Risk R2). Sideload-only APK via GitHub Releases.
- Running AI models on the phone. The model runs at a provider (OpenRouter, DeepSeek, xAI, etc.).
- Controlling other apps / the phone screen (no Shizuku, no accessibility service). Deliberately out of scope
  for safety, since this runs on the owner's main phone.

---

## 2. Target device & constraints

| Item | Value |
|---|---|
| Primary test phone | Samsung Galaxy M14 4G (arm64, 4–6 GB RAM, One UI) — owner's **main phone** |
| Min Android | 10 (API 29) for testing; aim to work on 11–15 |
| ABI | `arm64-v8a` only |
| Distribution | Signed APK on GitHub Releases, built by CI |
| Owner's dev setup | Mostly phone-based. **CI must build every APK**; owner installs from Releases. |

Samsung specifics the app must handle or guide in-app (one screen, with buttons that open the right settings page):
- **Auto Blocker** must be off to sideload (owner does this once before first install; document in README).
- "Put unused apps to sleep" / **Never sleeping apps** — request battery-optimisation exemption via the system
  dialog (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`), then deep-link to Samsung's battery page if still restricted.

---

## 3. Key technical decisions (read before coding)

### D1 — App stack: Flutter (Dart) + Kotlin platform code
Flutter for UI. Everything Android-specific (processes, foreground service, file extraction, boot receiver,
battery exemption) lives in Kotlin behind a `MethodChannel`/`EventChannel`.

### D2 — Run Linux ourselves: proot + Debian rootfs, `targetSdkVersion 28`
- Since Android 10, apps targeting SDK 29+ **cannot execute files they write to their own data folder**
  (SELinux W^X). Termux avoids this by targeting **SDK 28**; it is the proven path.
- Android 15/16/17 still install apps targeting SDK ≥ 24, so SDK 28 installs fine when sideloaded.
- Therefore: **`targetSdkVersion 28`**, `compileSdk` latest, `minSdk 29`.
- Runtime = **proot** (userspace chroot, no root needed) + **Debian (trixie, arm64) rootfs** extracted into
  `filesDir`. Hermes runs inside Debian as a normal Linux install.
- proot + libtalloc: use Termux's prebuilt arm64 binaries (or build with NDK in CI). They are GPL/LGPL:
  ship their license texts and a link to source in the app's "Open-source licenses" screen.
- Consequence: **Play Store is not possible on this path** (Play requires a recent targetSdk). Accepted.
  Revisit only if Termux's APK-library-file design or a jniLibs approach matures (Risk R2).

### D3 — Hermes is pinned, not "latest"
- Pin one Hermes **git commit** (latest stable tag at build time; at planning time the latest stable is
  v0.22.6 from 2026-11-03 — re-check). Record it in `runtime/HERMES_PIN`.
- Install inside Debian with Hermes's official Linux installer at that commit
  (`scripts/install.sh --non-interactive --commit <sha>` from `NousResearch/hermes-agent`).
- Upgrades ship as a new runtime image, never `hermes update` on the phone.

### D4 — Prebuilt runtime image (no on-phone compiling)
- CI builds **one tarball**: Debian rootfs + Hermes at the pin + Python deps + Chromium shared libs.
- Output: `runtime-<version>-arm64.tar.zst` + `.sha256` + `manifest.json`, published to GitHub Releases.
- The app downloads it on first launch, **verifies sha256 against a hash compiled into the app**
  (not one downloaded next to the file), then extracts.
- Reference implementation to study (MIT): `omarqaterge/hermes-mobile-app` →
  `tools/build-image.sh`, `tools/pack_image.py`, `.github/workflows/image.yml`, `phone/bootstrap.sh`,
  `phone/hermes-services`, `hermes/patches/`. Credit it in `THIRD_PARTY.md` if code is reused.

### D5 — How the app talks to Hermes
- Hermes runs `hermes dashboard --host 127.0.0.1 --port 9119 --no-open` inside proot.
  It serves Hermes's web UI and the `tui_gateway` JSON-RPC that Hermes Desktop uses.
- **v1 UI:** a WebView pointed at `http://127.0.0.1:9119`, wrapped in our native shell
  (status bar, settings, logs). Fastest path to a working app.
- **v2 UI:** native Flutter chat talking JSON-RPC directly. Port the TypeScript client from
  `hermes-agent/apps/shared` (also vendored in hermes-mobile-app `web/vendor/hermes-shared`) to Dart.
- This protocol is internal to Hermes and can change between versions → pinning (D3) protects us;
  every Hermes bump runs the contract tests (WBS 6.4).

### D6 — Process lifetime
- A **foreground service** (persistent notification "Agent running") owns the proot process.
- Supervisor restarts Hermes on crash with backoff; boot receiver restarts it after reboot (if enabled).
- Partial wake lock **only while a task is running**, never permanently.
- Android 12+ "phantom process killer" may kill child processes beyond 32 or under heavy CPU. We cannot
  disable it without adb. Mitigate: minimal process count, measure in the spike (WBS 1.5), show a clear
  in-app message + optional guide to the Android 14+ Developer-options toggle only if kills are detected.

### D7 — Safety defaults (main phone)
- Hermes bound to `127.0.0.1` only. Never `0.0.0.0`.
- Approval mode on by default for risky commands. "Full access" hidden behind a warning screen.
- Browser runs a **clean throwaway profile** by default (no real logins).
- No reading SMS, contacts, call log, location, camera, mic in v1.
- API keys stored only in Debian `~/.hermes/.env` (app-private storage); never logged, never in crash reports.
- No Shizuku, no accessibility service, no root.

---

## 4. Work Breakdown Structure

Format: **ID — Task** · Deliverable · Acceptance criteria · Depends on.
Every task ends with: code committed, CI green, notes added to `docs/DECISIONS.md` if a decision was made.

### Phase 0 — Repository & CI foundation
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 0.1 | Repo scaffolding | Flutter app (`app/`), `android/` Kotlin, `runtime/`, `docs/`, `tools/` | `flutter analyze` clean; folder layout documented in README | — |
| 0.2 | Gradle config | `minSdk 29`, `targetSdk 28`, `compileSdk` latest, `abiFilters arm64-v8a` | Build succeeds; manifest shows targetSdk 28 | 0.1 |
| 0.3 | Release signing | Keystore stored as GitHub Actions secrets (base64); never committed | CI produces a **signed** APK | 0.1 |
| 0.4 | CI: build APK | `.github/workflows/app.yml`: analyze, test, build release APK on push to `main` | Green run; APK artifact downloadable | 0.2, 0.3 |
| 0.5 | CI: publish release | On tag `v*`, attach APK to GitHub Release | Owner installs it on the M14 from the Release page | 0.4 |
| 0.6 | Docs skeleton | `README.md` (owner install steps incl. Samsung Auto Blocker), `docs/DECISIONS.md`, `THIRD_PARTY.md`, `LICENSE` | Present and accurate | 0.1 |

**Milestone M0:** "Hello" app installs on the M14 from a GitHub Release.

### Phase 1 — Technical spike (GO / NO-GO)
Goal: prove our own app can run Debian + Hermes with no Termux. **Stop and report to the owner after this phase.**
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 1.1 | Get proot binaries | proot + loader + libtalloc for arm64 (Termux prebuilt or NDK build in CI) | Binaries + license files in `runtime/proot/` | M0 |
| 1.2 | Extract & exec test | Kotlin: copy proot to `filesDir`, `chmod +x`, run `proot --version` | Output visible in an in-app debug screen | 1.1 |
| 1.3 | Minimal rootfs | Download a stock Debian arm64 rootfs (verified hash), extract, run `proot ... /bin/uname -a` | Prints Linux/aarch64 | 1.2 |
| 1.4 | Hermes manually | In debug screen: run the official installer at the pin inside Debian, then `hermes --version`, `hermes doctor` | Both succeed on the M14; time and disk use recorded | 1.3 |
| 1.5 | Survival test | Start `hermes dashboard` in a foreground service; lock screen 30 min; run a web-search chat | Still alive; record any phantom-process kills, RAM, battery drain | 1.4 |
| 1.6 | Spike report | `docs/SPIKE_REPORT.md` with numbers and a GO / NO-GO recommendation | Owner reviews and decides | 1.5 |

**Milestone M1 (decision gate):** GO → continue. NO-GO → fallback plan in §7.

### Phase 2 — Runtime image pipeline (CI)
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 2.1 | Image build script | `tools/build-runtime.sh`: Debian trixie arm64 (via qemu/binfmt or arm64 runner) + Hermes at pin + deps + Chromium libs | Reproducible tarball locally/CI | M1 |
| 2.2 | Apply patches | Optional Hermes patches in `runtime/patches/` applied at build | Build fails loudly if a patch doesn't apply | 2.1 |
| 2.3 | Pack & hash | `.tar.zst` + `.sha256` + `manifest.json` (version, hermes commit, size, sha256) | Files produced | 2.1 |
| 2.4 | CI workflow | `.github/workflows/runtime.yml` on tag `runtime-v*` → upload to Releases | Release assets present | 2.3 |
| 2.5 | Smoke test in CI | Boot image under qemu: `hermes --version` and `hermes doctor` | Workflow fails on regression | 2.4 |
| 2.6 | Size budget | Target ≤ 1 GB compressed; strip caches, docs, locales | Size recorded in manifest | 2.3 |

### Phase 3 — Runtime manager (in-app, Kotlin)
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 3.1 | Downloader | Resumable download (HTTP Range), progress events to Flutter, Wi-Fi-only option | Survives app kill + network drop; resumes | 2.4 |
| 3.2 | Verification | sha256 compared with value **compiled into the app build** for that runtime version | Corrupt/tampered file is rejected and deleted | 3.1 |
| 3.3 | Extraction | Stream-extract zstd tar into `filesDir/runtime/<version>/`, preserve symlinks & perms | `uname`, `python3`, `hermes --version` run | 3.2 |
| 3.4 | Storage check | Check free space before download (need ~2× image) | Clear message if not enough space | 3.1 |
| 3.5 | Versioning & upgrade | Install new runtime side-by-side, migrate `~/.hermes` (chats, memory, skills, keys), switch atomically, delete old | Upgrade keeps chats & settings | 3.3 |
| 3.6 | Repair & reset | "Repair runtime" (re-verify / re-extract) and "Reset everything" (with backup export) | Both work from Settings | 3.3 |

### Phase 4 — Process supervisor & lifecycle (Kotlin)
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 4.1 | Launch command | Single place building the proot command line (binds, env, `HOME`, tmp dir) | Unit-tested command builder | 3.3 |
| 4.2 | Foreground service | Owns the proot process; persistent notification with Stop button | Hermes keeps running with app closed | 4.1 |
| 4.3 | Health check | Poll `127.0.0.1:9119`; states: starting / ready / crashed / stopped → Flutter | UI shows correct state | 4.2 |
| 4.4 | Auto-restart | Restart on crash with exponential backoff; give up after N and notify | Kill process manually → recovers | 4.3 |
| 4.5 | Boot start | `BOOT_COMPLETED` receiver (toggle in Settings, default on) | Reboot → agent back within 2 min | 4.2 |
| 4.6 | Battery exemption | Request ignore-battery-optimisations; Samsung guidance screen with deep links | Status visible in Setup check | 4.2 |
| 4.7 | Logs | Ring-buffer logs (app + Hermes stdout/stderr), **secrets redacted**, "Share logs" button | Owner can send logs from the phone | 4.2 |
| 4.8 | Phantom-kill detection | Detect signal-9 deaths, count them, show guidance | Message appears only when kills happen | 4.4 |

### Phase 5 — Onboarding & settings UX (Flutter)
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 5.1 | Welcome flow | 3 screens: what it is → download (progress, size, ETA) → permissions | First run needs no terminal | 3.x, 4.x |
| 5.2 | Model connect: API key | Providers: OpenRouter, DeepSeek, OpenAI, Anthropic, Gemini; validate key with a test call; write via `hermes` config inside Debian | Wrong key → clear error; right key → ready | 4.3 |
| 5.3 | Model connect: subscriptions | Wrap Hermes's own OAuth flows (e.g. xAI Grok OAuth, Claude, ChatGPT, Nous Portal) — open browser, capture code | At least xAI Grok OAuth works | 5.2 |
| 5.4 | Model picker | Default model per chat + cheap "helper" model | Persisted | 5.2 |
| 5.5 | Setup check screen | Runtime ✓, agent running ✓, battery exemption ✓, notifications ✓, model ✓ — each with a Fix button | All green on the M14 | 4.x |
| 5.6 | Settings | Theme, Wi-Fi-only downloads, boot start, approval mode, browser profile, export/backup, licenses, about (app + runtime + Hermes versions) | All persisted | 5.1 |

**Milestone M2 (MVP):** install APK → tap through → chatting with Hermes in the WebView, survives screen-off & reboot.

### Phase 6 — Chat experience
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 6.1 | v1 WebView chat | WebView of `127.0.0.1:9119` inside native shell; file upload, back navigation, offline banner | Full chat works | M2 |
| 6.2 | Dart JSON-RPC client | Port of Hermes `apps/shared` client: sessions, streaming, tool events, approvals | Unit tests against recorded fixtures | 6.1 |
| 6.3 | v2 native chat | Flutter chat: streaming Markdown, tool cards, stop/retry, chat list & search | Feature parity with 6.1 for daily use | 6.2 |
| 6.4 | Contract tests | Recorded RPC fixtures per pinned Hermes version; CI fails if protocol shape changes | Runs on every Hermes pin bump | 6.2 |
| 6.5 | Share-to-agent | Android share sheet → new chat with text/URL/file | Works from Chrome | 6.1 |

### Phase 7 — Notifications & approvals
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 7.1 | Reply notifications | Notify when a long task finishes (app in background) | Received with app closed | 6.2 |
| 7.2 | Approval actions | Approve / Deny buttons on notifications for risky commands | Approval reaches Hermes; denial blocks the action | 6.2 |
| 7.3 | Cron results | Notify scheduled-job results; list jobs in app (view / run now / pause) | Works for a test cron | 6.2 |

### Phase 8 — Browser automation
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 8.1 | Local Chromium | Chromium + agent-browser in the runtime image; Hermes browser backend = local | "Open example.com and summarise" works | 2.x |
| 8.2 | Cloud browser option | Settings toggle for Browserbase / Browser Use / Firecrawl (owner's key) | Works when local is too heavy | 8.1 |
| 8.3 | Performance guard | Memory watchdog; one browser at a time; auto-close idle browser | No OOM kills on 4 GB device in a 1-hour test | 8.1 |
| 8.4 | Safe profile | Throwaway profile default; "real logins" mode off and behind warning | Default profile has no cookies | 8.1 |

### Phase 9 — Security & privacy hardening
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 9.1 | Local-only binding | Assert dashboard listens on 127.0.0.1; startup refuses otherwise | Port scan from LAN finds nothing | 4.2 |
| 9.2 | Local access token | If Hermes dashboard supports a session token, require it; WebView injects it. Otherwise document the risk | Other apps can't drive the agent without the token | 9.1 |
| 9.3 | Secret hygiene | Keys never in logs, crash reports, backups (unless user opts in) | Grep of exported logs finds no keys | 4.7 |
| 9.4 | Supply chain | Pinned Hermes commit, sha256 compiled in, signed APK, Dependabot for app deps | Documented in `docs/SECURITY.md` | 2.x, 3.2 |
| 9.5 | Threat model doc | `docs/SECURITY.md`: what we protect, what we can't (prompt injection, provider sees data) | Reviewed by owner | — |

### Phase 10 — SEO "employee" pack (the actual value)
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 10.1 | Skills bundle | Hermes skills shipped in the image: keyword research, SERP/competitor summary, content brief, blog draft, on-page SEO check, social post variants | Each runs from a chat command | M2 |
| 10.2 | Trend tracker | Scheduled job: daily trends in owner's niche (web search; X search if xAI provider) → notification digest | Digest arrives daily | 7.3 |
| 10.3 | Publishing | WordPress REST API publish **as draft only** (owner approves before publish) | Draft appears in WP admin | 10.1 |
| 10.4 | Pipeline view | Simple in-app board: Idea → Brief → Draft → Review → Published | Items move as jobs complete | 10.1 |
| 10.5 | Agent "team" config | Named agents/profiles with one narrow job each (Researcher, Writer, Editor, Publisher, Trend Watcher) | Profiles selectable per job | 10.1 |

### Phase 11 — QA, release & maintenance
| ID | Task | Deliverable | Acceptance | Deps |
|---|---|---|---|---|
| 11.1 | Test matrix | M14 4G (primary) + Android emulator API 30/34/35 arm64 in CI where possible | Results in `docs/TEST_MATRIX.md` | all |
| 11.2 | Soak test | 24 h run with one cron job every hour | ≥ 22/24 runs succeed; battery drain recorded | 7.3 |
| 11.3 | Update channel | In-app "update available" check against GitHub Releases (app + runtime) | Owner sees and installs updates from inside the app | 3.5 |
| 11.4 | Hermes bump playbook | `docs/HERMES_UPGRADE.md`: bump pin → build image → contract tests → soak → release | Followed for the first bump | 6.4 |
| 11.5 | v1.0 release | Tagged release with changelog | Owner uses it daily for a week | all |

---

## 5. Milestones & order

| Milestone | Contents | Rough effort with Claude Code* |
|---|---|---|
| **M0** Installable shell | Phase 0 | 1–2 days |
| **M1** GO/NO-GO | Phase 1 spike | 3–5 days |
| **M2** MVP | Phases 2–5 + 6.1 | 1.5–2.5 weeks |
| **M3** Daily driver | 6.2–6.5, 7, 8, 9 | 2–3 weeks |
| **M4** SEO employee | Phase 10 | 1–2 weeks |
| **v1.0** | Phase 11 | 1 week |

\*Estimates assume the owner tests each build on the phone within a day. Biggest uncertainty is Phase 1.

Critical path: 0.4 → 1.4 → 1.5 → 2.4 → 3.3 → 4.2 → 5.2 → 6.1 (= M2).

---

## 6. Risk register

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | proot + Hermes too slow / OOM on 4 GB M14 | Medium | High | Measure in 1.4–1.5; slim image; cloud browser (8.2); keep one browser |
| R2 | Future Android blocks targetSdk 28 or adds launch warnings | Low–Med (years) | High | Track Termux's APK-library-file work; isolate runtime launcher so it can be swapped for a jniLibs-based approach |
| R3 | Phantom process killer kills Hermes/Chromium | Medium | Medium | Few processes; detection + guidance (4.8); measure in 1.5 |
| R4 | Hermes internal protocol changes | High (per version) | Medium | Pin (D3); contract tests (6.4); WebView v1 is less coupled |
| R5 | Samsung battery management stops the service | Medium | Medium | Foreground service + exemption + Samsung guide screen (4.6) |
| R6 | Runtime image too large (> 1 GB) | Medium | Low | Strip, zstd -19, optional Chromium download later |
| R7 | Prompt injection via web pages | High | Medium–High | Approvals on, clean browser profile, drafts-only publishing, no phone-data access in v1 |
| R8 | GPL obligations for proot | Low | Low | Ship licenses + source links; proot runs as a separate program |
| R9 | API cost runaway | Medium | Medium | Owner uses capped keys; show token/cost per chat if Hermes exposes it |

---

## 7. Fallback if Phase 1 is NO-GO
1. **Plan B — Termux-backed app:** keep our Flutter app, but install Termux silently-as-possible like
   `hermes-mobile-app` does (F-Droid Termux + RUN_COMMAND). More setup steps for the user, proven to work.
2. **Plan C — Remote agent:** run Hermes on a small server/PC; the app becomes a remote client
   (same chat UI, connects over a secure tunnel). Zero phone setup; costs a few $/month.
The Flutter UI, chat client, and SEO pack are reused in every plan.

---

## 8. Definition of done (every task)
- Code merged to `main` via PR with a short description.
- CI green (analyze, tests, build).
- New decisions written to `docs/DECISIONS.md`.
- If it changes user-visible behaviour: tested on the M14 and noted in `CHANGELOG.md`.
- No secrets in code, logs, or commits.

## 9. References
- Hermes Agent: https://github.com/NousResearch/hermes-agent · docs: https://hermes-agent.nousresearch.com/docs/
- Reference app (MIT): https://github.com/omarqaterge/hermes-mobile-app
- Termux file layout / why targetSdk 28: https://github.com/termux/termux-packages/wiki/Termux-file-system-layout ·
  https://termux.dev/en/posts/general/2024/11/11/termux-selected-for-nlnet-ngi-mobifree-grant.html
- Min installable targetSdk by Android version: https://bayton.org/android/android-minimum-targetsdk-matrix/
- Executing binaries in an app (jniLibs approach, for future R2 work): https://dev.to/ai2th/pockr-part-2-executing-binaries-on-android-3b4k
