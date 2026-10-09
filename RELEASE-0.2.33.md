# Drone Remote Control 0.2.33-test

Experimental release with improvements for movement getting stuck near vehicles
and enemies.

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
in-game settings. Without it, Auto Aim, Seeker Homing Assist and Allow Multiplayer
remain OFF.

Do not enable multiple versions together. The `.sha256` asset is a checksum,
not another mod to import.

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

This is an experimental release. Game updates can break compatibility, and
crashes are possible. Surface avoidance is approximate; complex terrain, moving
enemies and deeply embedded Seekers can behave unexpectedly. The latest fixes
still need gameplay verification; not all getting-stuck issues are confirmed resolved.

**Multiplayer has not been verified in live gameplay.** Enabling it does not
guarantee reliable operation or host/client synchronization.
Anti-cheat compatibility and account safety are not guaranteed. Use at your own risk.

[Full guide and troubleshooting](https://github.com/pwj891129-arch/HD2-Drone-Remote-Control#readme)

## Patch Notes: 0.2.33

- Addressed surface-check errors that could stop movement near vehicles or after
  contact with enemies.
- Improved handling of outdated collision information and crowded scenes.
- Wall, terrain and vehicle avoidance remain enabled.

These fixes are experimental and still need gameplay verification.

## Changes Since The Previous GitHub Release (0.2.27)

- **0.2.32:** improved recovery from stuck flight, aiming after exiting control
  and interruptions caused by drone AI. Added a 100 m backpack-flight boundary
  with a 5-second return grace period for external overshoot, and reduced
  premature exits caused by temporary empty-ammo readings.
- **0.2.31:** fixed standard G-50 Seeker control entry.
- **0.2.30:** reduced processing during K-9 control and readiness display updates.
- **0.2.29:** combined all 14 option languages into one package, with automatic
  Text Language switching and English fallback.
- **0.2.28:** reduced repeated processing during control and HUD updates.

All changes above are included in **0.2.33**.
