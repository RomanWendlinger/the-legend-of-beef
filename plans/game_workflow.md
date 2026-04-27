# The Legend of Beef — Game Workflow

Snapshot of the player-facing flow, derived from the current codebase. Up to 4 players, local couch-coop, top-down 2D action with procedurally generated rooms.

---

## Boot

1. **Main menu** (`gui_elements/main_menu.tscn`) — entry point. Single-button start sends the user to the player select screen.
2. **Player select** (`gui_elements/player_select_screen.tscn`) — see below.
3. **Level** (`level/map1.tscn`) — procedurally generated rooms via the `wfc` plugin (`level/room_generator.gd`, `level/map_cluster.gd`). Spawns the active players at `player_spawn_point`-grouped nodes.

---

## Player select screen

Quartered layout, one slot per player (1–4). Each slot is its own state machine:

```
INACTIVE ─Btn1─▶ IDLE (character carousel)
                  ├──Btn1+guest──▶ GUEST_JOINED
                  └──Btn1+Bluesky──▶ BSKY_PENDING ──login──▶ BSKY_AUTHED ─┐
                                                                          │
GUEST_JOINED / BSKY_AUTHED ─stick L/R─▶ cycle weapon                       │
                           ─hold Btn1─▶ start level                        │
                                                                          │
BSKY_AUTHED ─Btn2─▶ BSKY_ALLOCATING (stat allocator) ──save──▶ BSKY_AUTHED◀┘
```

| State | What's visible | Stick L/R | Btn1 | Btn2 |
|---|---|---|---|---|
| **INACTIVE** | "Press Btn1 to join" | — | join → IDLE | — |
| **IDLE** | Character carousel: ◄ [sprite] *Name* ► (Granny / WZRD / FRBLL / fast_boi / Bluesky) | cycle character | confirm character | — |
| **BSKY_PENDING** | QR code (320×320) | — | cancel → IDLE | — |
| **BSKY_AUTHED** | StatPanel + Weapon carousel | cycle weapon | hold to start level | re-allocate stats → BSKY_ALLOCATING |
| **GUEST_JOINED** | StatPanel + Weapon carousel | cycle weapon | hold to start level | — |
| **BSKY_ALLOCATING** | StatAllocator (4 stat rows + Save/Cancel) | navigate/adjust | save (when valid) | cancel → BSKY_AUTHED |

### Bluesky login (the QR flow)

When a player picks Bluesky and confirms:

1. `AuthManager.start_login(slot, "bsky.app")` kicks off — generates PKCE + DPoP keypair locally.
2. Opens a session on the relay (`relay.the-legend-of-beef.todi.wtf`), holds a WebSocket open.
3. Performs PAR (Pushed Authorization Request) against bsky.social with DPoP-Nonce retry.
4. Displays the resulting authorize URL as a QR code in the player's slot.
5. Player scans with their phone, logs in to Bluesky, approves the requested scopes (`atproto repo:actor.rpg.stats repo:actor.rpg.sprite repo:actor.rpg.master blob:image/*`).
6. bsky.social redirects to the relay → relay pushes the auth code over the WebSocket → game does token exchange.
7. Game re-resolves the player's actual PDS from the DID (their PDS may differ from `bsky.app`'s).
8. Reads `actor.rpg.stats` from the PDS (existing build) + fetches the sprite from rpg.actor.
9. If no `the_legend_of_beef` entry exists yet, slot enters `BSKY_ALLOCATING` so the player can distribute their 24-point budget.
10. Otherwise slot enters `BSKY_AUTHED`, ready to start the level.

DPoP key never leaves the game. Tokens never touch the relay.

### Stat budget — the fairness anchor

Every character — guest or Bluesky — has the same 24-point budget across four stats:

- **VIT** → max HP (50 → 400 across 1 → 15)
- **STR** → weapon damage scale (60 → 260)
- **AGI** → movement speed (70 → 250)
- **TGH** → outbound knockback strength (40 → 240)

Levels 1–10 cost 1 budget point each; levels 11–15 cost 2 each (specialization tax). Maximum achievable single stat is 15 with the other three at 1 + 1 + 2.

Guest characters have pre-baked balanced builds. Bluesky players allocate via the in-game allocator.

---

## In-game loop

### Per-frame
- Movement: `velocity = direction * speed * delta` (Player_script.gd). Direction comes from `P{N} stick left/right/up/down`.
- Aiming: separate aim state (`States.AIMING`) drives the weapon's swing animation.
- Weapon attack: fires per `WeaponData.interval`, scales damage by `current_weapon_damage_scale`.
- Bluesky players: `AnimatedSprite2D` switches between `idle_<dir>` and `walk_<dir>` based on velocity. Shadow `AnimatedSprite2D` mirrors frames in lockstep.

### Pickups (`global_scripts/pickup_manager.gd`)
- Scattered through rooms. Pickup types include weapon-damage upgrades, coin grants, and beer bottles.
- Coins increment per-player counter (signal `coin_collected`).
- Beer affects the BeerManager state (drunk amount, weight, bottle count) — feeds the between-round mechanic.

### Combat
- Player has `HealthComponent` with `max_health` (from VIT). Damage from enemy contact / projectiles.
- `pushback_strength` (TGH) is applied to enemies you hit — outbound knockback, not damage resistance.
- `pushback_dampening` (`0.2` constant) controls how much the player resists incoming knockback.
- On lethal damage: emits `player_died(n)`. If all active players are dead → `all_player_died`.

### Round-end paths
- **Final boss defeated** → `final_boss_defeated(position)` → `create_level_end_hole(position)` → players walk into the hole → triggers level-completed flow.
- **All players die** → `all_player_died` → game over screen (`gui_elements/gameover.tscn`).
- **Single-player death** in coop → `managed_player_died(n)` → that player is out for the round, others continue.

### Beer time (`gui_elements/beertime/`)
A between-round mechanic. Player drunk-amount tracking persists in `BeerManager`:

- `drunk_amount` (ml accumulated)
- `bottle_drunk` (count)
- `current_bottle_max_volume` (330ml / 500ml)
- `current_weight` (kg, presumably affects buffs)

The intent (per code comments): every 250ml chugged at once gives a 25% stat bonus; the most-drunk player gets "the crown" (likely a visual/buff distinction). 100ml/6min is the optimal pacing.

---

## Persistence

| What | Persists across | Where |
|---|---|---|
| Bluesky-player stat builds | sessions | AT Proto record `actor.rpg.stats.the_legend_of_beef` on the player's PDS |
| Bluesky DID + handle | session only (no token storage on disk yet) | AuthManager in-memory |
| Guest character builds | code | `players/options/*.tres` |
| Selected weapon per slot | session only | `PlayerManager._selected_weapons` |
| Selected character per slot | session only | `PlayerManager._selected_characters` |
| Beer/drunk state | session only | `BeerManager.current_beer_stat` |
| Coins per player | session only | `PlayerManager.player_dict[n].coin_count` |

Nothing besides the Bluesky stat record is persisted between game launches. Refresh-token rotation is not implemented; if an access token expires mid-session, the round-end save would fail (gracefully — game continues, stats stay local for that session).

---

## Open follow-ups

- **Refresh-token rotation** — for sessions longer than the access token's TTL.
- **Round-end auto-save for Bluesky players** — currently only manual via the allocator. Auto-write the build at level completion.
- **Custom lexicon** — user is considering a "character as a service" PDS schema separate from `actor.rpg.stats`.
- **Bluesky logo for the carousel option** — currently text-only.
- **Refresh-token flow** for long sessions where the access token expires.
- **Refactor `pushback_strength` semantics or rename TGH** — currently TGH = outbound knockback, not defensive resistance.
