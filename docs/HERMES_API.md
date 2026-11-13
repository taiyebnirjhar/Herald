# Hermes API: what Herald uses

Source: Hermes Agent pinned at `v2026.9.24` (commit `f97608f`). Read from `gateway/platforms/api_server.py` and `api_server_openai_routes.py`.

Herald runs this API with `hermes gateway run` on `127.0.0.1:8642`. Every request needs `Authorization: Bearer <key>`. The key is at least 16 characters and is made on the phone (`ApiKey.kt`).

**Verified** means the route and its behaviour were read in the pinned source. **To check** means the request or response shape still needs reading before we build on it.

## Health and models
| Route | Use | Status |
|---|---|---|
| `GET /health` | Is the server up? Returns `{"status":"ok","platform":"hermes-agent","version":...}` | Verified |
| `GET /v1/models` | List models. The virtual model `hermes-agent` means the gateway default | Verified |
| `GET /v1/skills`, `GET /v1/toolsets` | What Hermes can do with its skills and tools | Verified (route) |

## Chat (release 0.2, built)
| Route | Use | Status |
|---|---|---|
| `POST /v1/chat/completions` | Chat with streaming (`stream: true`). Used by `HermesApi` | Verified |
| `POST /v1/responses` | OpenAI Responses format, with stored responses | Verified (route) |

## Runs and approvals (release 0.4)
| Route | Use | Status |
|---|---|---|
| `POST /v1/runs` | Start a durable run (survives a reconnect) | Verified (route) |
| `GET /v1/runs/{run_id}` | Run status | Verified (route) |
| `GET /v1/runs/{run_id}/events` | Live events for a run, for progress | Verified (route). To check: event format |
| `POST /v1/runs/{run_id}/approval` | Approve or deny a risky action. This is what the approval buttons will call | Verified (route). To check: request body |
| `POST /v1/runs/{run_id}/steer` | Redirect a running task | Verified (route) |
| `POST /v1/runs/{run_id}/stop` | Stop a run | Verified (route) |

## Sessions: saved chats (release 0.3)
| Route | Use | Status |
|---|---|---|
| `GET /api/sessions` | List chats. Hermes keeps them, so Herald doesn't have to | Verified |
| `POST /api/sessions` | Start a chat | Verified |
| `GET /api/sessions/{id}` | One chat | Verified |
| `PATCH /api/sessions/{id}` | Rename or update a chat | Verified |
| `DELETE /api/sessions/{id}` | Delete a chat | Verified |
| `GET /api/sessions/{id}/messages` | Messages in a chat | Verified |
| `POST /api/sessions/{id}/chat` and `/chat/stream` | Chat inside a saved session | Verified |
| `POST /api/sessions/{id}/fork` | Branch a chat | Verified |
| `POST /api/sessions/{id}/model` | Lock the model for a chat | Verified |

## Scheduled jobs (release 0.3)
| Route | Use | Status |
|---|---|---|
| `GET /api/jobs` | List jobs. `?include_disabled=true` also shows paused ones | Verified |
| `POST /api/jobs` | Create a job | Verified |
| `GET /api/jobs/{job_id}` | One job | Verified |
| `PATCH /api/jobs/{job_id}` | Change a job | Verified |
| `DELETE /api/jobs/{job_id}` | Delete a job | Verified |
| `POST /api/jobs/{job_id}/pause` | Pause | Verified |
| `POST /api/jobs/{job_id}/resume` | Resume | Verified |
| `POST /api/jobs/{job_id}/run` | Run now. Optional body `{"prompt": "..."}` for one run | Verified |

## Security notes from the source
- The server listens on loopback only when Herald starts it (`API_SERVER_HOST=127.0.0.1`).
- The server refuses to start without a key of 16 characters or more.
- Named profiles fail closed: a profile with no key of its own gets a 401, not the default key.

## Open items before release 0.4
- Read the approval request body and the run event format.
- Confirm how a job's results reach the phone (a notification, or a session message). This decides how 0.3.4 works.
