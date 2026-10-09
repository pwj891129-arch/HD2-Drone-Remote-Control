# HD2 Drone Remote Control

**0.2.27 experimental prerelease for Helldivers 2. Solo by default.**

[한국어 안내 및 변경 기록](README-KO.md) | [Downloads](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases)

[0.2.27 Test Release](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases/tag/drone-remote-control-0.2.27-test)

[Previously Published 0.2.22 Test Release](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases/tag/drone-remote-control-0.2.22-test)

This is a native-control prototype, not a stable release. Offline tests and
read-only checks of game connections passed. Actual Seeker camera takeover,
movement, detonation and surface clearance have not been tested in game.
Native calls can still crash the game despite ownership and code guards.

### Changed In 0.2.27

- K-9 adds a second HUD line: **ARC READY percent, progress bar and remaining
  wait**. It reads the ArcWeaponComponent countdown and current instance fire
  interval. It is next-shot readiness, not guessed button-hold charge. The
  observed instance interval was 5 s; this is not hardcoded. Reading failure
  shows `--` and does not disable movement or camera control.
- Character contacts must now match **Actor.name entries explicitly listed in
  Health named damage zones**. Live Titan inspection found 54 listed actors
  and two separate unlisted actors. The latter no longer become clearance
  planes. Authored hit shapes can still differ from the visible mesh.
- Bounded all-hit sweeps keep the nearest accepted contact after ignoring broad
  hulls, so ignored hulls cannot hide an actual limb or wall. Body clearance
  remains **1 cm**. When a moving body envelops the drone, only that body's
  contacts are ignored until the drone escapes; walls/floors remain active.
- Solid initial overlap uses reverse exit probes or a bounded signed penetration
  depth with a validated outward normal. Unknown solid interiors still hold
  flight. Sensors remain 50 ms, with at most 14 normal + 14 reverse sweeps;
  each sweep's private output holds up to 32 hits.
- Own-body exclusion, Guard Dog terrain margin **1 m**, Seeker terrain margin
  **0.5 m**, Seeker entry delay **0.5 s** and multiplayer default **OFF** remain.

Replace the old mod with one **0.2.27 EN/KO ZIP**, deploy and fully restart.
Offline regressions pass; the new HUD, Titan gaps and wall escape still need
in-game verification. Earlier notes below describe historical policies.

### Changed In 0.2.26

- The 0.2.25 live log confirms repeated `surface_hit_geometry_invalid`
  immediately after Guard Dog takeover. Body exclusion happened after checking
  contact geometry, so an initial-overlap placeholder could hold all flight.
- Own character, backpack and gun are excluded **before** reading contact
  geometry. Broad character movement hulls no longer become obstacle planes.
- Other players and identified enemies use the **native projectile collision
  filter**, verified against the game's projectile settings and registered
  physics filters, with **1 cm (0.01 m)** clearance. The previous generic
  `damage` filter is not used. Sensing uses a tiny 1 mm half-extent probe;
  exact per-model limb-gap passage still requires in-game verification.
- A zero-distance initial overlap is not interpreted as a surface. A bounded
  reverse sweep seeks the same UnitRef/ActorRef boundary from outside. Only the
  nearest verified exit is retained, avoiding opposing placeholder normals.
  Escape uses gradual outward movement, not a teleport or collision impulse.
- If no exit can be verified within 4 m, flight still holds. This does not
  promise escape from arbitrary deep solid geometry. Ownership and world
  guards remain enabled. Normal scans use at most 14 sweeps; overlap recovery
  can add one reverse sweep per hit, at most 28 total, on the 50 ms sensor.
- Terrain margins remain **1 m for Guard Dogs / 0.5 m for Seekers**. The
  0.5 s Seeker entry delay, Q detonation removal and other 0.2.25 changes remain.

Replace the previous mod with one local **0.2.26 EN/KO ZIP**, deploy and fully
restart. Offline regressions and read-only filter checks are separate from
live flight testing. Test Guard Dog entry near your character, Seeker entry
near a wall/floor and passage between enemy legs. `surface clearance: ready
(initial overlap recovered)` identifies a successful exit-face query.
Earlier version notes below describe their historical policy.

### Changed In 0.2.25

- Seeker takeover now waits **0.5 seconds** of continuous native deployment.
  This is not a teleport or guaranteed release from a wall.
- **Aim Mode Switch (Q) no longer detonates or cancels Seeker control**.
  A fresh Attack press still detonates. Native explosion, the 30-second
  lifetime from deployment and ownership/focus safety exits remain enabled.
- Same-owner Seeker component storage can relocate without ending control.
  The captured actor/unit/generation and camera root must remain identical;
  only copied leased bytes or the exact original state can be rebound.
  Unverified values, foreign ownership and duplicate still-live storage are
  never recaptured. Offline relocation regressions pass, but the reported
  random cancellation cause is not confirmed: the previous live log was empty.
- Events are appended and closed immediately instead of depending on the
  loader's buffered `flush`. Exit records include reason and control duration.
- **Player/identified enemy body blocking is temporarily disabled**, for
  both modes. Even damage hulls may fill visible leg gaps. This permits body
  traversal too; per-limb avoidance is not implemented. Walls/floors retain
  backpack **1 m** and Seeker **0.5 m** margins. Unclassified objects keep
  their existing obstacle treatment.

Replace the previous mod with one local **0.2.25 EN/KO ZIP**, deploy and fully
restart. Live continuity and body-passage behavior still require testing.
Earlier notes below are historical, not the current body/entry/key policy.

### Changed In 0.2.24

- **Allow Multiplayer** is an independent in-game toggle, default **OFF**.
  ON permits 2-4 party members, but still requires one local player and the
  exact owned backpack/held Seeker. No foreign drone adoption or network
  authority transfer is added. OFF in a party exits and restores AI, camera
  and inputs without requesting an extra Seeker explosion. Host/guest behavior
  has not been tested; multiplayer is experimental.
- Player and identified enemy bodies now use **0.1 cm = 1 mm = 0.001 m**
  clearance for both drone modes. Native UnitRef-to-entity lookup distinguishes
  character bodies from terrain/destructibles; `damage` is not assumed to mean
  a character. A compact reviewed archetype set excludes equipment, forcefields,
  stationary turrets and spawners. Unknown archetypes retain terrain clearance.
- Body damage surfaces supply the body avoidance planes, not their broader
  movement hulls. Private damage sensing half-extents are reduced from 20 cm to
  1 mm; the original geometry probe keeps its 20 cm half-extents. This avoids
  artificially filling leg gaps. Actual body damage shapes can still
  fill a visually open gap; passage and moving-body accuracy need live testing.
  Wall/floor margins remain **1 m for backpacks / 0.5 m for Seekers**.
- Classification is bounded to the hit units and cached within each scan.
  No entity-list scan, collision impulse, teleport or actor collision change
  is added. Existing 50 ms sensing and at most 14 sweeps are retained.

Offline regression and archive checks passed. Fully exit the game, replace
the old mod with one local **0.2.24 EN/KO ZIP**, deploy and restart. These new
live behaviors are not yet verified. Earlier version notes below describe
their historical scope, not the current multiplayer or body-margin policy.

### Changed In 0.2.23

- Seeker camera/control takeover waits **1 second of continuous native
  deployment**, after releasing throw/attack. Interrupted deployment restarts
  this wait. Focus loss, party join or native detonation cancels it without
  capturing player input. The 30-second lifetime still begins at deployment.
  This is a settling delay, not a teleport or guaranteed escape from a wall.
- Surface sensing also queries the game's registered `damage` filter. Player
  bodies, the owner's body/backpack and enemy body shapes can supply avoidance
  planes, in addition to existing wall/floor sensing. Each 50 ms scan uses at
  most 14 private sweeps, with duplicate planes removed. No physical collision
  response or entity-list scan was added. Clearance remains 1 m for backpacks
  and 0.5 m for Seekers; actual body hits still need live verification.
- **Seeker Homing Assist**, a separate in-game toggle, defaults **OFF**. OFF
  pauses enemy-seeking behavior. ON reads identity-checked native selected
  targets and uses the same inertial, surface-aware movement as manual flight;
  native autonomous flight stays paused. Movement keys and mouse input override
  assistance immediately and for 0.35 s after the last manual input.
- Known original-state resets on the same owned Seeker renew manual capture
  instead of exiting into native enemy pursuit. Unknown state changes still
  fail closed and restore player control. HUD displays the homing mode.

Offline regressions and read-only engine/filter registration checks passed.
These new live behaviors are not yet verified. Replace the old package with
one local 0.2.23 EN/KO ZIP, deploy and fully restart before testing.

### Fixed In 0.2.22

Passive Guard Dog lookup failures no longer erase Seeker Q/G edge history.
Quick Throw creates a held Seeker during its animation; capture now waits up
to 3 seconds for this exact owned, attached inventory item. Live read-only
records showed ballistic state 2 moving directly to active seek state 4,
so both airborne states 3 and 4 are accepted, with native motion still required.
Attached units, ballistic-only state 2, foreign/recycled identities and party
joins are still refused. No flying-unit search or synthetic throw was added.

Detonation immediately releases AI, movement and pose overrides so native
explosion/destruction processing can run. Only an identity-checked, already
exploded unit's meshes are hidden; no unit deletion, damage or effect override
is used. The frozen camera/input hold alone lasts 0.7 seconds. Regression tests
passed; these fixes still require confirmation after installing the new ZIP.

### Quick Throw And Explosion View

Hold mapped Aim Mode Switch and use mapped **Quick Throw** (currently Q+G) to
prepare Seeker control without equipping slot 4. The same owned inventory item
must still be attached to this actor before its native deployment is tracked.
If it is not available immediately, the mod waits at most 3 seconds to capture
it; it never searches for nearby launched drones. The original Q+Attack route
is retained. Both require releasing the throw/attack key and waiting 0.5 seconds
after continuous deployment before takeover.

After requested or observed detonation, the last camera position and rotation
stay frozen for **0.7 seconds**, then player view/input and companion handling
are restored. The hold does not access or move the destroyed drone and does not
accept another attack. Focus loss, invalid bindings, actor/camera replacement,
party join with Allow Multiplayer OFF, or shutdown interrupt it safely. In-game Q+G takeover and explosion
timing are not yet verified; offline regression tests passed.

## Installation

1. Completely exit the game. Download **one** EN or KO ZIP from Releases.
   They have the same runtime; the Arsenal descriptions differ.
2. Import it into Arsenal, replace the previous Drone Remote Control version,
   and enable its **Backpack and Seeker Control** option.
3. Deploy with **Bingus Shared Loader / API 1**, then restart the game.
   The loader is required and is not bundled.

Mod Options Menu (API 1, version 3+) is optional, for backpack **Auto Aim** and
**Seeker Homing Assist**, and **Allow Multiplayer**. All default OFF without it. They are independent
settings; labels follow game text language (Korean/English, English fallback).
HUD+, HD2 Helper and Vehicle Dual Control are not
required. The runtime includes cooperation with compatible HD2 Helper versions
to suspend wheel/reload input handling during drone control.

Do not run multiple versions of this mod together. Python, diagnostic scripts
and development dependencies are not required to play.

## Controls

Controls follow the game's keyboard/mouse bindings. Q and T below refer to the
author's current Aim Mode Switch and Backpack Function bindings, not fixed keys.

| Mode | Enter | Move | Exit |
| --- | --- | --- | --- |
| Guard Dog backpack | Hold Aim Mode Switch and press Backpack Function; release both | Movement keys; Dodge up; Crouch down; mouse aim; Attack fires | Backpack Function; ammo/heat or signal limit |
| G-50 / G-60 Seeker | Hold Aim Mode Switch and use Quick Throw; or equip slot 4, hold Aim Mode Switch, press then **release** Attack | Same movement and camera controls | Fresh Attack requests detonation; Q does nothing; 30-second timeout; 0.7-second explosion view |

Backpack targets: Guard Dog, Rover, Hot Dog, K-9 and Dog Breath. Ownership is
checked through the worn backpack; nearby unrelated drones are not adopted.
Preparation may recall and redeploy the drone before camera takeover.

Backpacks have a 100 m signal range. Empty ammunition or full overheat returns
control to native AI; the mod does not refill ammunition. Seekers have no range
limit or return function. Throw-release and a continuously held Q are not
detonation inputs. The exact held Seeker must detach and remain deployed for
0.5 seconds before takeover. Native detonation during this wait cancels entry.

Both modes are solo-only by default. Allow Multiplayer ON permits parties,
while retaining own-drone checks. A party join with that option OFF, lost focus,
invalid ownership or an error ends control and attempts restoration without
requesting an extra Seeker explosion.

## Status And Limitations

- Rover keyboard movement was confirmed in an earlier user test. New Guard Dog
  family connections and G-60 held-object connections were checked read-only;
  that does not prove live remote control works for each family.
- Nonphysical terrain clearance is approximate: 1 m for backpacks, 0.5 m for
  Seekers; other player/identified enemy projectile hit shapes use 0.01 m.
  Own character/equipment is excluded. Complex surfaces,
  moving bodies and leg gaps need live testing; the delay does
  not guarantee recovery of a grenade already deeply embedded in geometry.
- Crosshair convergence, body tracking and shot effects still need live testing.
  The mod does not forcibly freeze the player's body rotation.
- Game-build and ownership guards may intentionally refuse control after an
  incompatible game update. Multiplayer is opt-in and unverified; guests may
  lack authority or observe replication differences.
- No claim of anti-cheat compatibility or account safety is made. Test at your
  own risk and fully restart the game after replacing or removing the mod.

## Development

Python 3.10+ and Lupa's LuaJIT 2.1 runtime are used for offline tests:

```powershell
python -m pip install -r requirements-dev.txt
python test.py
python build.py
```

The build runs the tests, emits deterministic EN/KO ZIPs into `releases/`, and
verifies their Lua archive payloads and SHA-256 manifests. It does not install
the mod, access the game process or publish a release.

`tools/` contains read-only development probes, not required runtime code. Live
probes currently depend on the separate private Vehicle Dual Control camera
reader and are not a standalone diagnostic distribution. Offline fixtures do
not need that project. Optional checks against local retained game images are
skipped when those images are absent; no game binaries or memory captures are
distributed. Only compact Guard Dog/body identity catalogs are included.

`publish.ps1` publishes already-built packages after their source commit has
been pushed. It verifies GitHub asset digests before making a prerelease public.
