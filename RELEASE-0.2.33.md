# Drone Remote Control 0.2.33-test

Experimental vehicle/body surface-wait correction; live verification required.

The Nexus Mods page was accidentally deleted while uploading an update.
Releases and updates will be provided on GitHub until the page is restored.
Sorry for the inconvenience, and thank you for your patience.

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

Also includes the changes developed since the previous GitHub release, 0.2.27:

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

Fully exit Helldivers 2, replace the old mod in Arsenal with
`Drone-Remote-Control-0.2.33-private-test.zip`, deploy and restart.
Bingus Shared Loader / API 1 is required; Mod Options Menu / API 1 version 3+
is optional. Multiplayer remains experimental and defaults OFF.
