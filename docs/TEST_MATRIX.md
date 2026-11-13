# Test matrix

What is tested, where, and by whom. The phone is the only real test for anything that touches Android, Hermes running on the phone, or memory. CI and this machine check the code, not the phone.

**Phone:** Samsung Galaxy M14 4G (4 GB RAM, arm64, Android 14/15). Owner tests on Wi-Fi.

## Where tests run
| Check | Where | When |
|---|---|---|
| `flutter analyze`, `flutter test` | CI and local | Every PR |
| Kotlin unit tests | CI and local | Every PR |
| APK checks (signature, targetSdk 28, arm64 only) | CI | Every PR |
| Phone tests | Owner's M14 | Each release candidate |

## Phone tests by release

### Gate (release 0.2 → 0.3)
| # | Test | Steps | Pass when | Status |
|---|---|---|---|---|
| G1 | Linux base sets up | Setup > Set up on Linux base | Done, with progress shown | Owner test pending |
| G2 | Hermes installs | Setup > Install on Hermes Agent | Done, version shown | Owner test pending |
| G3 | Hermes starts | Settings or chat > Start Hermes | Status says running within 30 s | Owner test pending |
| G4 | Survives the screen being locked | Start Hermes, lock 30 min, unlock | Still running | Owner test pending |
| G5 | Key saved and a reply comes back | Settings > AI > save OpenRouter key; chat | Reply appears | Owner test pending |
| G6 | Memory, both engines | Run the native chat and the web screen together (release 0.3) | Phone stays usable; no kill of Hermes | Next |

### Release 0.3
| # | Test | Steps | Pass when | Status |
|---|---|---|---|---|
| R3-1 | Web screen opens | Open the web tab | Hermes's dashboard loads | Next |
| R3-2 | Notification on reply | Lock the phone, start a long reply | A notification arrives when the reply is done | Next |
| R3-3 | Jobs list | Open jobs; create a test job; run it now; pause; resume | Each step works and the list updates | Next |
| R3-4 | Restart | Restart the phone with "start after restart" on | Hermes is running within 2 minutes | Owner test pending (built) |
| R3-5 | Battery screen | Settings > Keep Hermes running > Allow | Status changes to allowed | Owner test pending (built) |

### Release 0.4
| # | Test | Steps | Pass when | Status |
|---|---|---|---|---|
| R4-1 | Approve and deny | Ask an agent for a risky action | Approve runs it; deny stops it | Next |
| R4-2 | Profiles | Switch between two agent profiles | Each keeps its own memory and role | Next |
| R4-3 | Browser runs headless | Ask for a page check | No window on screen; the phone stays usable | Later |

### Release 0.5 and 1.0
| # | Test | Steps | Pass when | Status |
|---|---|---|---|---|
| R5-1 | Update Hermes | Update to the next pinned version | Chats and keys still there | Next |
| R5-2 | Backup and restore | Back up, then restore on a clean install | Chats and keys come back | Next |
| R5-3 | One week of use (1.0) | Use it daily | Hermes runs every day; no lost work | Owner, after 1.0 candidate |

## Results log
Record each phone test here with the date, the release, the result and the log text if it failed.

| Date | Release | Test | Result | Notes |
|---|---|---|---|---|
| | | | | |
