# Third-party code and licences

Phase 0 ships only Flutter and its Dart/Android dependencies (BSD-3-Clause, via the Flutter
SDK and pub packages). Nothing else is bundled yet.

Planned (not in this build yet, see PLAN.md §3 and §4):

| Component | Licence | Phase | Notes |
| --- | --- | --- | --- |
| Hermes Agent (NousResearch) | MIT | 1+ | Pinned commit, `runtime/HERMES_PIN` |
| omarqaterge/hermes-mobile-app | MIT | 1+ | Reference only; credit when code is reused |
| proot | GPL-2.0 | 1+ | Ship licence text and a source link in the app |
| libtalloc | LGPL-3.0 | 1+ | Ship licence text and a source link in the app |
| Debian rootfs packages | various (mostly GPL/MIT/BSD) | 1+ | Licence texts shipped with the image |
