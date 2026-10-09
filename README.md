# HD2 Drone Remote Control

**0.2.20 experimental prerelease for Helldivers 2. Solo only.**

[한국어 안내 및 변경 기록](README-KO.md) | [Downloads](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control/releases)

This is a native-control prototype, not a stable release. Offline tests and
read-only checks of game connections passed. Actual Seeker camera takeover,
movement, detonation and surface clearance have not been tested in game.
Native calls can still crash the game despite ownership and code guards.

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
| G-50 / G-60 Seeker | Equip the throwable in slot 4; hold Aim Mode Switch; press then **release** Attack for the normal throw | Same movement and camera controls | Fresh Attack or Aim Mode Switch requests detonation; 30-second timeout |

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
