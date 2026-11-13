# Third-party code and licences

Flutter and its Dart/Android dependencies (BSD-3-Clause, via the Flutter SDK and pub packages).

Bundled in the app (WBS 1.1, `runtime/proot/`):

| Component | Licence | Licence text | Source |
| --- | --- | --- | --- |
| proot 5.1.107.102 (Termux build) | GPL-2.0-or-later | `runtime/proot/licenses/GPL-2.0.txt`, `GPL-3.0.txt` | Termux packages, see `runtime/proot/README.md` |
| libtalloc 2.5.0 (Termux build) | LGPL-3.0 | `runtime/proot/licenses/LGPL-3.0.txt` | same |
| libandroid-shmem 0.7 (Termux build) | see the Termux package | same | same |

Planned (not in this build yet, see PLAN.md §3 and §4):

| Component | Licence | Phase | Notes |
| --- | --- | --- | --- |
| Hermes Agent (NousResearch) | MIT | 1+ | Pinned commit, `runtime/HERMES_PIN` |
| omarqaterge/hermes-mobile-app | MIT | 1+ | Reference only; credit when code is reused |
| proot | GPL-2.0 | 1+ | Ship licence text and a source link in the app |
| libtalloc | LGPL-3.0 | 1+ | Ship licence text and a source link in the app |
| Debian rootfs packages | various (mostly GPL/MIT/BSD) | 1+ | Licence texts shipped with the image |
