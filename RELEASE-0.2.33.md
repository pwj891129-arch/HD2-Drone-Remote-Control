# Drone Remote Control 0.2.33-test

Experimental vehicle/body surface-wait correction; live verification required.

The Nexus Mods page was accidentally deleted while uploading an update.
I've contacted Nexus Mods to request a restoration. If the page cannot be
restored, I'll re-upload the mod on a new page.
Releases and updates will be provided on GitHub until the page is restored.
Sorry for the inconvenience, and thank you for your patience.

## Description

Directly control your Guard Dog or Seeker with a third-person camera, keyboard
movement, mouse aiming and manual attacks. Supports Guard Dog, Rover, Hot Dog,
K-9, Dog Breath, G-50 Seeker and G-60 Anti-Tank Seeker.

Includes smooth inertial flight, approximate surface avoidance, distance/ammo/heat
HUD information and K-9 next-shot readiness with a progress bar and remaining wait.
This is an experimental release; multiplayer is optional and OFF by default.

## Installation And Requirements

1. Completely exit Helldivers 2.
2. Download **Drone-Remote-Control-0.2.33-private-test.zip** from the assets below.
3. Import the single multilingual ZIP into **Arsenal**, replacing the old version.
4. Enable **Backpack and Seeker Control**, deploy with **Bingus Shared Loader**,
   then restart the game.

**Bingus Shared Loader / API 1 is required and not bundled.**
**Bingus's Mod Options Menu / API 1, version 3+** is optional for changing the
in-game settings. HUD+, HD2 Helper and Vehicle Dual Control are not required.
Do not enable multiple versions together. The `.sha256` asset is a checksum,
not another mod to import. Python and diagnostic tools are not required to play.

## Controls

**Use the keys or mouse buttons assigned to these actions in your game settings,
not fixed keyboard letters.** Switch Aim Mode is also called Aim Mode Switch;
Fire is also referred to as Attack.

### Guard Dog Backpacks

**Start with the drone fully docked on your backpack.**

1. Equip the backpack during a mission. If the drone is airborne, recall it with
   **Use Backpack Function** and wait until it is fully docked.
2. Hold **Switch Aim Mode**, press **Use Backpack Function**, then release both.
3. Wait for deployment preparation and camera takeover.
4. Press **Use Backpack Function** again during control to exit.

Backpack range is **100 m**. Outward movement is restricted at the boundary;
external overshoot gets **5 seconds** to return. Confirmed empty ammo or full
overheat returns control to native AI; no ammunition is refilled by the mod.

### Seeker Drones

Hold **Switch Aim Mode**, use **Quick Throw** (Quick Throwable / Quick Grenade),
then release both. Control starts after **0.5 seconds of stable deployment**.

Alternatively, use **Equip Throwable** (Throwable / Grenade), hold **Switch Aim
Mode**, press and release **Fire** to throw, then release Switch Aim Mode.

A **new Fire press** during control requests detonation. **Switch Aim Mode does
not detonate the Seeker or exit control.** Seekers have **no range limit**, no
return function and a **30-second lifetime from deployment**. The camera holds
the last view for **0.7 seconds after explosion** before returning to the player.

### Movement And Attack

- **Move Forward / Backward / Left / Right**: horizontal flight.
- **Dive / Dodge**: ascend.
- **Crouch**: descend.
- **Camera / Look**: look and aim.
- **Fire / Attack**: fire the backpack weapon or detonate the Seeker.

## In-Game Options And Languages

With Bingus's Mod Options Menu installed, select **Drone Remote Control** in the
in-game mod options menu. Its title follows your Text Language.

- **Auto Aim**: backpack target tracking. Default **OFF**.
- **Seeker Homing Assist**: enemy-seeking assistance; movement/mouse input takes
  priority. Default **OFF**.
- **Allow Multiplayer**: enables own-drone control in a party for both modes.
  Default **OFF**. Experimental and unverified in live multiplayer sessions.

One ZIP includes all option translations and automatically follows the game's
**Text Language**, with **English fallback** for unsupported or missing text.
Supported: English, French, Italian, German, Spanish, Latin American Spanish,
Japanese, Korean, Brazilian Portuguese, Portuguese, Polish, Russian, Simplified
Chinese and Traditional Chinese. No online translation or extra language pack
is needed. Arsenal labels remain English; HUD status text is not localized.

## Important Notes

Game updates can break compatibility and native control can still crash the game.
Surface avoidance is approximate, not exact mesh collision; complex terrain,
moving bodies and deeply embedded Seekers can behave unexpectedly. Latest
surface-wait corrections still require live verification.

**Multiplayer has not been verified in live gameplay.** Enabling it does not
guarantee network authority, reliable guest behavior or host/client synchronization.
Anti-cheat compatibility and account safety are not guaranteed. Use at your own risk.

[Full guide and troubleshooting](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control#controls)

## Patch Notes: 0.2.33

- Separate collision classification from drone transform-accessor validation.
  Vehicle props remain obstacles without requiring the drone accessor layout.
- Treat inactive/recycled Actor references as absent damage parts, matching the
  native lookup. Unreadable layouts, changed registries and foreign owners still
  refuse movement; body hit-part filtering and 1 cm clearance remain enabled.
- Retry all-hit overflow using a bounded 128-row private buffer. Normal queries
  retain 32 rows; incomplete results never authorize motion. Ordinary scans make
  at most 14 casts; combined overlap/overflow recovery is bounded to 70 casts.
- Preserve terrain/vehicle avoidance, movement/camera ownership guards, the
  0.2.32 recovery and range behavior, and the unified 14-language option menu.
- No separate key configuration or automatic installation.
- Local research JSON and observation records are excluded from this package.

## Changes Since The Previous GitHub Release (0.2.27)

- Unified 14-language in-game options with automatic Text Language selection and
  English fallback. One ZIP replaces separate English/Korean packages.
- Standard G-50 Seeker support using its own native AI behavior profile.
- Reduced repeated native reads, cached binding discovery and K-9 display sampling.
- Restore manual aim activation on exit; recover exact owned native AI/aim resets.
- Limit outward backpack flight at 100m, with 5s return grace for external overshoot.
- Confirm empty ammunition for 0.2s, without changing or refilling ammunition.
- Narrow terrain-overlap rechecks, retired-unit filtering and native AI release
  after 2s of persistent backpack surface-query failure.

0.2.32 gameplay logs showed `unit_accessor` beside vehicles,
`body_part_registry_bounds` during monster contact and a 45-hit overflow.
Read-only live engine inspection confirms native Actor absence handling and
bounded query-output conversion. 121 Python tests plus Lua regression suites
pass offline. Actual vehicle/body contact with this build still needs testing;
this is not a claim that all getting-stuck reports are resolved.

All of these changes are included in 0.2.33; intermediate local test packages
are not required. Installation instructions above apply to the assets below.
