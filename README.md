# HD2 Drone Remote Control

**0.2.22 experimental build for Helldivers 2. Solo only.**

[한국어 안내 및 변경 기록](README-KO.md) | [Downloads](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases)

[0.2.22 Test Release](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases/tag/drone-remote-control-0.2.22-test)

This is a native-control prototype, not a stable release. Offline tests and
read-only checks of game connections passed. Actual Seeker camera takeover,
movement, detonation and surface clearance have not been tested in game.
Native calls can still crash the game despite ownership and code guards.

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
is retained. Both require releasing the throw/attack key before takeover.

After requested or observed detonation, the last camera position and rotation
stay frozen for **0.7 seconds**, then player view/input and companion handling
are restored. The hold does not access or move the destroyed drone and does not
accept another attack. Focus loss, invalid bindings, actor/camera replacement,
party join or shutdown interrupt it safely. In-game Q+G takeover and explosion
timing are not yet verified; offline regression tests passed.

## Installation

1. Completely exit the game. Download **one** EN or KO ZIP from Releases.
   They have the same runtime; the Arsenal descriptions differ.
2. Import it into Arsenal, replace the previous Drone Remote Control version,
   and enable its **Backpack and Seeker Control** option.
3. Deploy with **Bingus Shared Loader / API 1**, then restart the game.
   The loader is required and is not bundled.

Mod Options Menu is optional, for the backpack Auto Aim setting. Without it,
manual aim is the default. HUD+, HD2 Helper and Vehicle Dual Control are not
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
| G-50 / G-60 Seeker | Hold Aim Mode Switch and use Quick Throw; or equip slot 4, hold Aim Mode Switch, press then **release** Attack | Same movement and camera controls | Fresh Attack or Aim Mode Switch requests detonation; 30-second timeout; 0.7-second explosion view |

Backpack targets: Guard Dog, Rover, Hot Dog, K-9 and Dog Breath. Ownership is
checked through the worn backpack; nearby unrelated drones are not adopted.
Preparation may recall and redeploy the drone before camera takeover.

Backpacks have a 100 m signal range. Empty ammunition or full overheat returns
control to native AI; the mod does not refill ammunition. Seekers have no range
limit or return function. Throw-release and a continuously held Q are not
detonation inputs. The exact held Seeker must detach and deploy before takeover.

Both modes require no other party members. A party join, lost focus, invalid
ownership or an error ends control and attempts restoration without requesting
an extra Seeker explosion.

## Status And Limitations

- Rover keyboard movement was confirmed in an earlier user test. New Guard Dog
  family connections and G-60 held-object connections were checked read-only;
  that does not prove live remote control works for each family.
- Nonphysical surface clearance is approximate: 1 m for backpacks, 0.5 m for
  Seekers. It is not a guarantee against passing through every complex surface.
- Crosshair convergence, body tracking and shot effects still need live testing.
  The mod does not forcibly freeze the player's body rotation.
- Game-build and ownership guards may intentionally refuse control after an
  incompatible game update. This prototype does not support multiplayer use.
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
distributed. Only the compact Guard Dog identity catalog is included.

`publish.ps1` publishes already-built packages after their source commit has
been pushed. It verifies GitHub asset digests before making a prerelease public.
