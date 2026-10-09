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

This is an **experimental release**. Game updates can break compatibility, and
crashes are possible.

Surface avoidance is approximate, not exact mesh collision. Complex terrain,
moving enemies and deeply embedded Seekers can cause unexpected behavior.
The latest fixes still need gameplay verification; not all getting-stuck issues
are confirmed resolved.

**Multiplayer is experimental, OFF by default and unverified in live gameplay.**
Correct operation and synchronization are not guaranteed for hosts or guests.
Focus loss or a safety check may end control and return the player's view/input.

Anti-cheat compatibility and account safety are not guaranteed. Use at your own risk.

## Patch Notes

### 0.2.33

- Addressed surface-check errors that could stop movement near vehicles or after
  contact with enemies.
- Improved handling of outdated collision information and crowded scenes.
- Wall, terrain and vehicle avoidance remain enabled.

These fixes are experimental and still need gameplay verification.

### Changes Since The Previous GitHub Release (0.2.27)

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

[0.2.33 release notes](RELEASE-0.2.33.md)
