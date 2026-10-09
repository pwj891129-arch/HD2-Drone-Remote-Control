# HD2 Drone Remote Control

**0.2.33 experimental test build for Helldivers 2. Solo by default.**

[한국어 안내 및 변경 기록](README-KO.md) | [Downloads](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases)

### Nexus Mods Page Notice

I accidentally deleted the mod page on Nexus Mods while uploading an update.
I've contacted Nexus Mods to request a restoration. If the page cannot be
restored, I'll re-upload the mod on a new page.
Until the page is restored, releases and updates will be available on GitHub.
Sorry for the inconvenience, and thank you for your patience.

[Download 0.2.33](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases/tag/drone-remote-control-0.2.33-test)

[Installation](#installation) | [Controls](#controls) | [Options](#in-game-options)
| [Languages](#languages) | [Patch Notes](#patch-notes)

## Description

Take direct control of your Guard Dog or Seeker drone with a third-person camera,
keyboard movement, mouse aiming and manual attacks.

Drone Remote Control is an experimental mod for Helldivers 2. Solo play is enabled
by default; multiplayer is available through an optional in-game setting.

## Main Features

- Supports Guard Dog, Rover, Hot Dog, K-9 and Dog Breath backpacks.
- Supports G-50 Seeker and G-60 Anti-Tank Seeker throwables.
- Uses your configured game keyboard and mouse bindings, not fixed hotkeys.
- Smooth inertial movement with approximate, nonphysical surface avoidance.
- Distance, ammunition and heat information on the drone HUD.
- K-9 next-shot readiness with a progress bar and remaining wait time.
- Independent Auto Aim, Seeker Homing Assist and Allow Multiplayer options,
  all **OFF by default**.
- One multilingual package with automatic in-game option language selection.

## Requirements

- **Arsenal** for importing and deploying the mod.
- **Bingus Shared Loader / API 1**, required and not bundled.
- **Bingus's Mod Options Menu / API 1, version 3 or newer**, optional for changing
  the in-game assistance and multiplayer settings.

HUD+, HD2 Helper and Vehicle Dual Control are not required. Python, diagnostic
scripts and development dependencies are not required to play.

## Installation

1. Completely exit Helldivers 2.
2. Download **Drone-Remote-Control-0.2.33-private-test.zip** from
   [the latest release](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases/tag/drone-remote-control-0.2.33-test).
3. Import the single multilingual ZIP into Arsenal and replace the previous
   Drone Remote Control version.
4. Enable **Backpack and Seeker Control**, deploy with Bingus Shared Loader,
   then restart the game.

Do not enable multiple versions of this mod at the same time. The optional
`.sha256` file is a download checksum, not another mod to import.

## Controls

**All controls use the keyboard or mouse button assigned to the action in your
game settings.** The names below refer to game actions, not fixed keys.
Switch Aim Mode is also called Aim Mode Switch; Fire is also referred to as Attack.

### Guard Dog Backpacks

**Start remote control with the drone fully docked on your backpack.**

1. Equip a supported Guard Dog backpack during a mission.
2. Press **Use Backpack Function** to recall the drone if it is airborne, and wait
   until it is fully attached to your backpack.
3. Hold **Switch Aim Mode**, press **Use Backpack Function**, then release both inputs.
4. Wait for docking/deployment preparation and camera takeover to finish.
5. During remote control, press **Use Backpack Function** again to exit.

Backpack drones are limited to **100 m** from the player. Outward movement is
restricted at the boundary; inward and tangential movement remain available.
If an external movement pushes the drone beyond range, it has **5 seconds** to
return before control ends. Confirmed empty ammunition or full overheat returns
control to native AI. The mod does not refill ammunition.

### Seeker Drones

Hold **Switch Aim Mode**, use **Quick Throw** (Quick Throwable / Quick Grenade),
then release both inputs. Control starts after deployment has remained stable
for **0.5 seconds**.

Alternatively:

1. Use **Equip Throwable** (Throwable / Grenade) to hold the Seeker in your hand.
2. Hold **Switch Aim Mode**, press and release **Fire** to throw it.
3. Release **Switch Aim Mode** and wait for control to begin.

During remote control, a **new Fire press** requests detonation. **Switch Aim
Mode does not detonate the Seeker or exit control.**

Seekers have **no range limit** and no return function. Their lifetime is
**30 seconds from deployment**. After an explosion, the camera stays at the last
view for **0.7 seconds** before returning to the player.

### Movement And Attack

- **Move Forward / Backward / Left / Right**: horizontal flight.
- **Dive / Dodge**: ascend.
- **Crouch**: descend.
- **Camera / Look**: look and aim.
- **Fire / Attack**: fire the backpack drone's weapon or detonate the Seeker.

## In-Game Options

With Bingus's Mod Options Menu installed, open the in-game mod options menu and
select **Drone Remote Control** (its title follows your Text Language).

- **Auto Aim**: enables backpack-drone target tracking. Default **OFF**.
- **Seeker Homing Assist**: enables enemy-seeking assistance. Movement and mouse
  input take priority. Default **OFF**.
- **Allow Multiplayer**: permits control of your own drones with other party
  members present. Applies to both modes. Default **OFF**.

Without the option-menu mod, these settings remain OFF. Multiplayer has not been
verified in live gameplay; turning it on does not guarantee authority or reliable
host/client synchronization.

## Languages

**One ZIP contains every option-menu translation.** Separate English and Korean
downloads are no longer needed.

In-game mod titles, option names and descriptions automatically follow the game's
**Text Language** setting. Unsupported languages and missing translations fall
back to English.

Supported languages: English, French, Italian, German, Spanish, Latin American
Spanish, Japanese, Korean, Brazilian Portuguese, Portuguese, Polish, Russian,
Simplified Chinese and Traditional Chinese.

Translations are local; no internet connection or extra language pack is required.
Arsenal labels remain English. Drone HUD status messages are not included in this
option-menu localization.

## Troubleshooting

- Check that Bingus Shared Loader is installed, the mod is enabled and deployed,
  and only one version is active. Fully restart after replacing a package.
- For backpack drones, start with the drone fully docked, then use your configured
  **Switch Aim Mode + Use Backpack Function** actions and release both inputs.
- If another party member is present, enable **Allow Multiplayer** to try the
  experimental multiplayer mode.
- If control is refused, check `DroneRemoteControl.log` for the refusal/exit reason.
  Keyboard/mouse bindings must be supported by the mod; controller support is not
  promised. A surface-query failure may temporarily hold flight for safety.

## Important Notes

This is an **experimental release**, not a stable or crash-free mod. Game updates
can break compatibility, and native control calls can still crash the game.

Surface avoidance is approximate, not exact rendered-mesh collision. Complex
terrain, moving enemies and deeply embedded Seekers can behave unexpectedly.
The latest vehicle/body surface-wait corrections pass offline regression tests
but still need live gameplay verification. Not every getting-stuck report is
claimed resolved. Crosshair convergence, shot effects and body tracking also
remain areas for further testing. Player body rotation is not forcibly frozen.

**Multiplayer is experimental, OFF by default and unverified in live gameplay.**
Correct operation and synchronization are not guaranteed for hosts or guests.
An invalid owner, focus loss or a safety error may end control and restore the
player's view/input; only your own drone is eligible for control.

Anti-cheat compatibility and account safety are not guaranteed. Use at your own
risk. Local research JSON and observation records are excluded from new downloads.

## Patch Notes

### 0.2.33

- Corrected unnecessary drone-transform checks when classifying vehicle props
  and other collision objects.
- Treat inactive/recycled body-part references as absent parts instead of
  stopping the entire surface scan.
- Retry dense collision results with a bounded 128-hit buffer; incomplete scans
  still do not authorize movement.
- Preserve terrain avoidance, 1 cm body clearance and strict owned-drone checks.
- Exclude local research records from the downloadable package.

### Changes Since The Previous GitHub Release (0.2.27)

- **0.2.32:** terrain-overlap rechecks, retired-object filtering, aim-state
  restoration, owned AI-reset recovery, 100 m boundary handling with 5 s overshoot
  grace, and 0.2 s empty-ammunition confirmation.
- **0.2.31:** corrected standard G-50 Seeker capture using its own AI profile.
- **0.2.30:** reduced K-9 native-reader calls and capped readiness display sampling
  at 100 ms. Mock measurements are not an in-game FPS guarantee.
- **0.2.29:** combined all 14 option languages into one package, with automatic
  Text Language switching and English fallback.
- **0.2.28:** capped HUD refresh at 100 ms, cached binding discovery for 250 ms,
  skipped unnecessary idle discovery and reduced repeated native reads/writes.

These changes are included in **0.2.33**; intermediate local test packages do not
need to be installed. The latest build passes **121 Python tests plus Lua
regressions**, separately from live gameplay testing.

[0.2.33 release notes](RELEASE-0.2.33.md) |
[Previous 0.2.27 release](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases/tag/drone-remote-control-0.2.27-test)

<details>
<summary>Detailed patch notes and development history</summary>

Older entries below describe historical behavior and local test packages.
Use the current installation and controls above.

### Changed In 0.2.33

- Separate collision identity from the drone transform accessor check. Authored
  props and body sub-units with different accessors no longer abort classification.
  Owned drone position, movement and camera validation remain strict.
- Match the native Actor lookup's absent-handle behavior: inactive or recycled
  actor references are not live damage parts. Unreadable/changed registries,
  incorrect live owners and unsupported layouts still hold flight.
- Retry all-hit overflow with a private **128-row** buffer before consuming any
  results. Ordinary scans retain 32 rows and at most 14 casts; overlap/overflow
  recovery has a conservative 70-cast ceiling. No truncated scan permits movement.
- Keep terrain/vehicle avoidance, 1 cm body clearance, named damage-part filtering,
  the 0.2.32 recovery behavior, unified languages and configured game bindings.

0.2.32 gameplay logs show `unit_accessor` beside parked vehicles and
`body_part_registry_bounds` during monster contact, plus a 45-hit overflow.
Read-only engine inspection confirms the absent-Actor branch and bounded output
conversion. Offline regressions cover these paths; the new runtime still needs
actual vehicle/body-contact testing. Apply
**Drone-Remote-Control-0.2.33-private-test.zip** after fully exiting, deploy and
restart. Installation is not automatic; GitHub release assets are published separately.

### Changed In 0.2.32

- A terrain-box initial overlap gets a **2 cm centre-probe retry** before being
  treated as a solid interior. Real wall normals and the existing reverse-probe
  recovery stay active. Ordinary scans still use at most 14 casts every 50 ms;
  overlap recovery is bounded to 35 casts. Body clearance remains 1 cm.
- Collision hits from **proven retired UnitRef generations** are ignored before
  classification. Live debris and unknown/static hits remain blocking. This does
  not remove every destroyed object's collider or bypass unreadable geometry.
- A backpack surface-query failure lasting **2 s** releases manual control and
  restores native AI/player input instead of leaving an indefinite frozen view.
  Short failures still hold flight without authorizing motion through walls.
- Manual LookAt activation is restored on exit, including same-owner storage
  relocation. Exact owned native AI and aim resets can recover outside the old
  one-second fire window; foreign behavior/mode/identity changes still refuse.
- Backpack **outward movement is limited at 100 m** without an immediate exit.
  Inward/tangential inputs remain usable. External overshoot has **5 s** to return;
  the HUD shows `RANGE LIMIT` or the remaining `SIGNAL RETURN` time. Seeker range
  remains unlimited. Surface avoidance takes priority when constraints conflict.
- Empty feed is confirmed for **0.2 s** with firing disabled during confirmation.
  Transient empty samples can recover; no ammo is added or rewritten. Exit logs
  include the last magazine, chamber, effective ammo, reserve and heat values.
- The unified option languages and configured game bindings are unchanged.
  Separate mod-key configuration has not been added.

Offline tests pass. Prone entry, broken props, Hot Dog recall/reentry, remaining
ammo and physical boundary behavior still require live testing; these reports
are not claimed fully resolved. Stationary K-9 fixture writes over 120 frames
drop **360 -> 240**, with reads **185,664 -> 185,904** (+0.13%). This is not an FPS
benchmark. Replace with **Drone-Remote-Control-0.2.32-private-test.zip**, deploy
and restart after fully exiting. Not automatically installed or published.

### Changed In 0.2.31

- Fixed standard **G-50 Seeker** capture being rejected by the G-60-only AI-kind
  check. Live read-only observations show G-50 uses **621**, not G-60's **4**.
- Both native identities are now applied consistently to held/quick-throw capture,
  manual flight, homing validation and exact AI restoration after control.
- Regression tests cover both throw routes, native AI resets, homing ON/OFF,
  detonation and camera/input restoration for each family. Foreign ownership,
  recycled units and unexpected behavior kinds still fail closed.
- The **0.5 s deployment delay**, **30 s lifetime**, **0.7 s explosion view**,
  multilingual options and existing performance improvements are unchanged.

G-50 held state 1 and detached flight states 3/4 were checked read-only in a solo
mission. This confirms native values, not successful flight with the modified
runtime. Apply **Drone-Remote-Control-0.2.31-private-test.zip** after fully exiting
the game, deploy and restart to test both throw routes and manual detonation.
This build is not automatically installed or published.

### Changed In 0.2.30

- K-9 Arc readiness is a display-only sample every **100 ms**, matching the HUD.
  It no longer resolves the Arc component every control frame. Owner changes
  and clock rewinds discard the sample; failures retry on the next scheduled poll.
  Ammunition, overheating, firing eligibility and control checks remain live.
- Component identity checks read a small contiguous manager header in one call.
  Root, map, count, owner pointer, descriptor and row-pointer checks remain fresh
  on every validation. No component values are reused across frames.
- A bounded **64-entry unit-address cache** avoids repeated object discovery.
  Every lookup still reads the current registry, generation, slot, object identity
  and accessor. Changed objects cannot pass on the strength of cached addresses.
- Movement, mouse aim, firing, native transform updates, body clearance and
  restoration timing are unchanged. The unified 14-locale option menu remains.

Stationary, non-firing K-9 mock workload over 120 frames: **246,960 -> 185,664
memory-read calls** (24.8% fewer). Read volume is **2,691,240 -> 2,790,360 bytes**
because batches include intervening header bytes. This measures native-reader
crossings, not reduced allocation size or in-game FPS. The mock excludes real
physics, rendering and native engine cost, so live comparison is still required.

Use **Drone-Remote-Control-0.2.30-private-test.zip**, replacing the old mod after
fully exiting. Deploy and restart. Compare K-9 control OFF/ON without firing,
then movement, camera turning, charging and shooting. This build is neither
automatically installed nor published.

### Changed In 0.2.29

- One multilingual ZIP replaces separate English/Korean packages. Arsenal
  metadata defaults to English; no language pack or online translator is needed.
- In-game mod title, all three option names and their descriptions follow the
  game's **Text Language**: English, French, Italian, German, Spanish, Latin
  American Spanish, Japanese, Korean, Brazilian Portuguese, Portuguese, Polish,
  Russian, Simplified Chinese and Traditional Chinese. Unknown/unreadable
  languages and missing translations fall back to English.
- Language changes are detected at most every **250 ms**, including switching
  away from Korean and back. Rendering labels performs no memory reads.
  Saved ON/OFF values and stable option IDs are preserved without re-registration.
- All 0.2.28 performance optimizations remain. Drone HUD status text is unchanged;
  this translation catalog covers the in-game option menu only.

Use **Drone-Remote-Control-0.2.29-private-test.zip**. Fully exit the game, replace
the old mod in Arsenal, deploy and restart. Offline language-switching, fallback,
option persistence and regression tests are included; live menu glyph rendering
and FPS comparison still need testing. This build is not automatically installed
or published. The old Korean manifest is retained as a source reference only.

### Changed In 0.2.28

- HUD layout, GUI-world discovery and text refresh run at most once every
  **100 ms**. Unchanged text objects remain on screen instead of being rebuilt.
- Binding discovery reuses parsed keys for **250 ms**, while binding payloads
  are still checked before use. Changes or replaced tables force rediscovery.
- Idle frames sample hotkeys without resolving unused backpack or Seeker
  ownership/camera graphs. The entry modifier wakes discovery immediately.
- Native memory reads and float conversions reuse bounded FFI buffers. Reads
  still copy current memory and refuse partial/failed results; memory contents
  are not cached across frames.
- Repeated snapshot checks and duplicate movement-time pose queries are removed.
  Fresh ownership, parent, generation, lease-byte and restore checks remain.
- Unchanged lease values are validated but not written again. Authored body-part
  names use a bounded 64-model cache, checked against table/slot identities.
- Surface scans stay at **50 ms** even while rapidly changing direction. Six
  axial probes continue to cover nearby surfaces. External displacement drops
  stale samples and holds motion until a scheduled fresh query succeeds.
- Movement, camera and firing remain per-frame. Existing range, clearance,
  Seeker timing and default-OFF assistance/multiplayer settings are unchanged.

Offline fixture comparison: snapshot reads **862 -> 750**; total binding reads
over 120 validated frames **10,078,560 -> 400,144 bytes**. These are mock workload
counts, not an in-game FPS benchmark. Live FPS/stutter and input/avoidance tests
are still required. This build has not been published or automatically installed.

Completely exit, replace the old mod with one **0.2.28 EN/KO ZIP**, deploy and
restart. Compare the same drone/scene with control OFF and ON, including K-9
firing, fast turns, walls, Seeker Aim Mode Switch + Quick Throw and return to player control.

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
  0.5 s Seeker entry delay, Aim Mode Switch detonation removal and other 0.2.25 changes remain.

Replace the previous mod with one local **0.2.26 EN/KO ZIP**, deploy and fully
restart. Offline regressions and read-only filter checks are separate from
live flight testing. Test Guard Dog entry near your character, Seeker entry
near a wall/floor and passage between enemy legs. `surface clearance: ready
(initial overlap recovered)` identifies a successful exit-face query.
Earlier version notes below describe their historical policy.

### Changed In 0.2.25

- Seeker takeover now waits **0.5 seconds** of continuous native deployment.
  This is not a teleport or guaranteed release from a wall.
- **Aim Mode Switch no longer detonates or cancels Seeker control**.
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

Passive Guard Dog lookup failures no longer erase Seeker Aim Mode Switch / Quick Throw edge history.
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

Hold mapped Aim Mode Switch and use mapped **Quick Throw** to
prepare Seeker control without using Equip Throwable. The same owned inventory item
must still be attached to this actor before its native deployment is tracked.
If it is not available immediately, the mod waits at most 3 seconds to capture
it; it never searches for nearby launched drones. The original Aim Mode Switch + Attack route
is retained. Both require releasing the throw/attack key and waiting 0.5 seconds
after continuous deployment before takeover.

After requested or observed detonation, the last camera position and rotation
stay frozen for **0.7 seconds**, then player view/input and companion handling
are restored. The hold does not access or move the destroyed drone and does not
accept another attack. Focus loss, invalid bindings, actor/camera replacement,
party join with Allow Multiplayer OFF, or shutdown interrupt it safely. In-game Aim Mode Switch + Quick Throw takeover and explosion
timing are not yet verified; offline regression tests passed.

</details>

## Development

Python 3.10+ and Lupa's LuaJIT 2.1 runtime are used for offline tests:

```powershell
python -m pip install -r requirements-dev.txt
python test.py
python build.py
```

The build runs the tests, emits one deterministic multilingual ZIP into
`releases/`, and verifies its Lua archive payload and SHA-256 manifest. It does not install
the mod, access the game process or publish a release.

`tools/` contains read-only development probes, not required runtime code. Live
probes currently depend on the separate private Vehicle Dual Control camera
reader and are not a standalone diagnostic distribution. Offline fixtures do
not need that project. Optional checks against local retained game images are
skipped when those images are absent; no game binaries or memory captures are
distributed. Local research JSON and observation records are excluded from new
packages and are not required for the public offline tests or runtime.

`publish.ps1` publishes already-built packages after their source commit has
been pushed. It verifies GitHub asset digests before making a prerelease public.
