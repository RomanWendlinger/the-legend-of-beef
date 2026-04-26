# RPG.Actor / AT Protocol Integration Plan

Status: design accepted, not yet implemented
Last updated: 2026-04-26

## Goal

Let players log into The Legend of Beef with their Bluesky account via a QR code scanned on their phone, pull their RPG.Actor sprite and stats from AT Proto, play with a build constrained by a fair point budget, and persist their stats back to their own PDS at the end of the run. Predefined guest characters (granny, WZRD, FRBLL, fast_boi) keep working without any login or internet, so couch-coop never breaks.

Plugin under evaluation: https://github.com/TechTastic/godot-rpg-actor (MIT, Godot 4).

---

## Architecture overview

Three independent pieces:

1. **Game (Godot 4.4)** — guest characters stay as-is with pre-baked balanced builds. A new "Login with Bluesky" option per player slot triggers the QR flow, fetches sprite + stats, validates them against the point budget, and spawns a player parameterized at runtime.
2. **Relay (todi.wtf, configurable + open-source)** — a small service hosting OAuth `client-metadata.json`, an HTTP `/login/callback` endpoint, and a WebSocket session router that funnels OAuth auth codes back to the running game. Defaults to `https://todi.wtf`; players can point the game at any conforming relay (their own self-hosted, or community-run).
3. **AT Proto record** — game-specific stats stored under our own `systemName: "the_legend_of_beef"` inside the shared `actor.rpg.stats` record so we don't trample other games using the same plugin.

---

## Stat budget design

**24 points across 4 stats. Each stat: 1–10. Base balanced build = 6/6/6/6.**

| Stat | Maps to | Min → Max effect (suggested) |
|---|---|---|
| **VIT** (vitality) | `HealthComponent.max_health` | 50 → 200 |
| **STR** (strength) | `current_weapon_damage_scale` (Player_script.gd) | 60 → 160 |
| **AGI** (agility) | `speed` (Player_script.gd) | 70 → 150 |
| **TGH** (toughness) | `pushback_strength` (Player_script.gd) | 40 → 140 |

**Why 24 / 4 / 1–10:**
- 24 = 6 × 4, so the balanced build is a clean reference point.
- 1–10 lets specialists exist (e.g. 10/8/4/2 glass cannon) without dominating — soft floors and ceilings keep extreme builds playable but not broken.
- Pre-baked guest characters live in the same budget, so a Bluesky import can never out-stat them. **This is the fairness anchor — fairness is structural, not policed.**

**Validation rules** (applied to stats imported from AT Proto):
- Sum > 24 → reject; show "stats exceed budget, please re-allocate" and use defaults until the player runs the in-game allocator.
- Stat outside [1, 10] → clamp.
- Missing stat → use default 6.
- Missing `systemName: "the_legend_of_beef"` entry → run the in-game allocator UI on first launch.

Pre-baked guest builds (suggested starting point — tune in Phase 0):
- granny: VIT 9 / STR 5 / AGI 4 / TGH 6 (tanky, slow)
- WZRD:   VIT 4 / STR 9 / AGI 6 / TGH 5 (caster, fragile)
- FRBLL:  VIT 6 / STR 7 / AGI 7 / TGH 4 (offense)
- fast_boi: VIT 4 / STR 5 / AGI 10 / TGH 5 (speed)

---

## Data flow per player slot

```
[Game]  player presses "Login with Bluesky" on slot N
        → POST relay/v1/login/start → receives session_id
        → opens WebSocket relay/v1/login/ws?session_id=...
        → generates PKCE verifier + DPoP keypair locally (kept on game)
        → builds OAuth authorize URL with state=session_id, code_challenge=...
        → displays QR encoding that authorize URL
[Phone] scan → opens browser → bsky.social authorize
        → user logs in, approves
        → bsky.social redirects to https://todi.wtf/v1/login/callback?code=...&state=session_id
[Relay] matches state → pushes auth code over WebSocket to game session
[Game]  exchanges code + verifier + DPoP proof for tokens (locally)
        → ATProto.get_record(pds, did, "actor.rpg.stats")
        → extract our systemName entry, validate against 24-point budget
        → RpgActor.get_sprite(did) → ImageTexture → swap into player scene
        → spawn player into the round
[End of round]
        → ATProto.merge_and_put_stats(pds, did, "the_legend_of_beef", new_stats)
```

Critical security property: **DPoP key never leaves the game.** The relay only sees the short-lived auth code, which it cannot redeem (PKCE verifier is on the game). A malicious relay can log handles/DIDs of who's logging in but cannot impersonate anyone or steal tokens.

---

## Persistence

Every authenticated user can write to their own PDS — that's what AT Proto is for. Standard `com.atproto.repo.putRecord` with their OAuth tokens + DPoP proof works for any Bluesky account, not just rpg.actor Creator Accounts. (The README's "Creator Account" reference is about a separate feature: spawning game-managed NPC characters on rpg.actor's own PDS. It does not restrict normal users from writing their own stats.)

**Three states:**
- **Logged-in (any Bluesky account)** → AT Proto is source of truth. Read on login, hold in memory for the session, write back at round end via `merge_and_put_stats`. Other systems' stats in the same record are preserved.
- **Guest character** → pre-baked build, no persistence needed.
- **Optional local cache** → a `user://profiles.cfg` keyed by DID, written alongside the AT Proto write. Useful only as an offline/transient fallback so the first frame after spawn doesn't stall on a network call. Not required for correctness.

Caveat: the plugin's writing API is flagged "experimental." Be defensive — handle write failures gracefully, retry once, do not block the round-end screen on a successful write.

---

## Relay design

**Endpoints (versioned from day one — keep stable across forks):**
- `GET  /.well-known/...` or `/client-metadata.json` — OAuth client metadata document with the `redirect_uri` baked in.
- `POST /v1/login/start` — game opens a session, gets a `session_id`.
- `GET  /v1/login/ws?session_id=...` — WebSocket; relay pushes the auth code when received.
- `GET  /v1/login/callback?code=...&state=...` — OAuth redirect target; relay matches `state` to a session and pushes the code over the matching WebSocket.

**Stack options (any of these works):**
- Cloudflare Workers + Durable Objects (free tier covers personal use, near-zero ops).
- Bun/Node + Express on Fly.io / Railway / a $5 VPS.
- Whatever the maintainer prefers. The protocol is small enough to reimplement in an afternoon.

**Repo layout (separate from this game repo):**
```
todi-wtf-rpg-actor-relay/
├── README.md          # Deploy guide: domain → TLS → deploy → point game at base URL
├── PROTOCOL.md        # Half-page spec of /v1/* contract (versioned)
├── client-metadata.json
├── src/               # The relay itself
└── deploy/
    ├── cloudflare-workers/
    └── docker/
```

**Configurable in the game:**
- Setting `auth_relay_url` (default `https://todi.wtf`) exposed in an Options screen.
- Switching relays requires re-authorization (OAuth `client_id` is per-domain — unavoidable property of OAuth client identity). Surface this clearly in the Options UI.

**What this de-risks:**
- todi.wtf goes down → players point at any other running relay; guests still work regardless.
- Abuse / rate limits → power users self-host.
- Maintainer loses interest → forks pick it up.

**What it does NOT solve:**
- Upstream changes to Bluesky's OAuth server require updating every deployed relay in lockstep with the plugin. Inherent to OAuth-on-a-third-party-service.

---

## Phased rollout

Each phase is shippable on its own. Stop at any phase and the game still works.

| Phase | Deliverable | Standalone value |
|---|---|---|
| **0** | Stat budget refactor: introduce VIT/STR/AGI/TGH on existing characters; pre-bake guest builds; wire stats into Player_script.gd + HealthComponent at spawn time. | Real stat system + build variety. No plugin needed. |
| **1** | Drop in `addons/rpg_actor`. Add manual-handle skin import: type a Bluesky handle → fetch sprite via `RpgActor.get_sprite(did)` (no auth required) → swap onto chosen guest character. | Validates the plugin and sprite pipeline with zero infra. |
| **2** | Stand up todi.wtf relay (separate repo, open-source). Build OAuth client metadata, callback, WebSocket router. Verify full OAuth round-trip with a test Bluesky account *before any Godot code is written*. | The hardest piece is debugged in isolation. |
| **3** | Game-side QR login UI per slot. Wire game ↔ relay protocol. Read stats from AT Proto under our `systemName`, validate against 24-point budget, swap in real sprite. In-game allocator UI for first-time logins. | Full read flow. Players see their identity in the game. |
| **4** | Write-back at round end via `merge_and_put_stats`. Defensive error handling, retry, optional local cache. | Closes the loop. Stats persist. |
| **5** *(optional)* | Bundled list of known-good relays with picker; community relay onboarding. | Raises the ceiling for non-technical self-hosting. |

**Recommended starting point: Phase 0.** It's pure local refactor, has no dependency on any of the AT Proto work, and immediately improves gameplay regardless of whether later phases ever ship.

---

## Pros

- **Fairness is structural**: the 24-point budget makes Bluesky imports incapable of pay-to-win regardless of what's in someone's AT Proto record. Validation is enforced at import time.
- **Couch-coop never breaks**: guest characters work fully offline. The Bluesky path is opt-in per slot. Internet outage = guest-only night, game still playable.
- **Phase 0 has standalone value**: even without ever touching the plugin, the stat refactor delivers build variety the game currently lacks.
- **Universal persistence**: every authenticated player can write stats back to their own PDS. No second-class users, no tier UX.
- **Relay is replaceable, not load-bearing**: open-source + configurable URL means todi.wtf going down doesn't brick the feature. Self-hosting is a documented path, not a hack.
- **Strong security posture**: DPoP keys + PKCE verifiers stay on the game machine. Even a malicious relay can only see auth codes it cannot redeem.
- **Forward-compatible**: same architecture supports adding stats, leveling, unlockables, achievements later without re-plumbing.

## Cons

- **Plugin's stock `ATProtoOAuth.login()` won't fit cross-device** — it assumes a localhost callback. The game will need to either fork the plugin's OAuth path or use lower-level `ATProto`/`XRPC` calls plus its own DPoP/PKCE handling. Expect to read the plugin's source carefully. `ATProtoOAuth.create_dpop_proof()` being exposed helps.
- **Sprite frame mismatch**: 144×192 plugin sheet vs. the game's current 32×32 region-rect Sprite2D model. Likely means the Bluesky path uses a different player scene with `AnimatedSprite2D` while guests stay on `Sprite2D + region_rect`. Two render paths to maintain. Resolved by knowing the exact frame layout of the rpg.actor 144×192 sheet.
- **4 simultaneous QR logins on screen** is a UI design problem of its own — fitting four QRs + status, handling timeouts, retries, "this slot logged in successfully, switch to slot 2", per-slot cancel.
- **OAuth client metadata is a semi-public commitment**: the registered `client_id` URL on todi.wtf is what users authorize against. Changing the URL later effectively orphans existing authorizations. Pin it from day one.
- **Each relay is a distinct OAuth client**: switching relays = re-authorize. Unavoidable property of OAuth client identity. Surface it clearly.
- **Plugin write API is "experimental"**: stability note, not access restriction, but build defensive error handling so a write failure at round end never blocks gameplay.
- **Relay maintenance is real, even if small**: a tiny service still needs domain renewal, TLS, occasional dependency updates, and someone watching for upstream Bluesky OAuth changes. Open-sourcing transfers some of this burden to a community that may or may not show up.
- **Relay protocol must stay stable across forks**: mismatched versions across deployments would break interop. Pinning `/v1/*` and writing a half-page `PROTOCOL.md` from day one is mandatory, not optional.

---

## Open questions to answer before Phase 2

1. **Exact frame layout of the rpg.actor 144×192 sprite sheet** — frame dimensions and animation order. Determines `AnimatedSprite2D` config for the Bluesky-path player scene.
2. **Bluesky OAuth `redirect_uri` constraints** — confirm that an OAuth client metadata document hosted at `https://todi.wtf/client-metadata.json` with a non-localhost redirect URI is accepted by bsky.social's authorization server. Quick check via Bluesky's OAuth docs / a manual round-trip before committing to relay code.
3. **Plugin OAuth fork-or-extend decision** — read `addons/rpg_actor/scripts/atproto_oauth.gd` (and adjacent files) to determine whether the cross-device flow can be built on the plugin's existing primitives or whether a parallel implementation alongside the plugin is cleaner.

---

## Reference: existing system this plugs into

Useful file:line refs for whoever picks this up:

- `project.godot` autoloads (line ~18-26): `PlayerManager`, `GuiManager`, `SignalBus`, `BeerManager`, `PickupManager`, `SceneSwitcher`, `ScalingManager`. New autoload `AuthManager` would slot in here.
- `global_scripts/player_manager.gd` `spawn_player()` (~line 70-97): currently hardcodes scene paths per `player_number`. Phase 3 generalizes this to spawn a parameterized scene with sprite + stats injected at runtime.
- `players/<character>/<character>.tscn` + `Player_script.gd`: `@export` stats (`speed`, `pushback_strength`, `current_weapon_damage_scale`, `coin_count`). Phase 0 replaces these with VIT/STR/AGI/TGH-derived values.
- `gui_elements/player_select_screen.tscn` + `.gd` (~line 56-81): per-slot input polling. Phase 3 adds the "Login with Bluesky" branch alongside the existing guest-character flow.
- `addons/`: currently only `kanban_tasks` and `wfc`. `rpg_actor` would be added in Phase 1.
