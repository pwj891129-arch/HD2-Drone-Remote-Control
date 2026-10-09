# Drone Remote Control 0.2.24 Test

Experimental prototype, not a stable release. Fully exit the game, replace
the previous drone package with one EN/KO ZIP, deploy and restart.

- Add independent **Allow Multiplayer**, default **OFF**. Both Guard Dog and
  Seeker modes permit parties when ON, but retain exact own-drone identity
  checks and one local player. No network authority transfer is added.
- Switching OFF in a party restores original AI, camera and input without
  requesting an extra Seeker explosion.
- Reduce player/identified enemy body clearance to **0.1 cm (1 mm / 0.001 m)**.
  Terrain stays at 1 m for backpacks and 0.5 m for Seekers.
- Use native UnitRef-to-entity identity checks and reviewed body archetypes;
  equipment, forcefields, stationary turrets and spawners are excluded.
  Unknown archetypes keep normal terrain clearance.
- Use body damage surfaces, not broad character movement hulls. Reduce private
  damage sensing half-extents from 20 cm to 1 mm to avoid artificially closing
  leg gaps; the original terrain probe remains 20 cm. Actual body shapes may
  still obstruct a visually open gap.
- Keep bounded hit-only classification, 50 ms sensing and at most 14 sweeps.
  No collision impulses, actor collision edits or teleports are added.

Offline regression and package checks passed. Live body hits, leg-gap passage
and host/guest multiplayer behavior still need testing. Guest authority and
replication differences may prevent control or cause desynchronization.

Bingus Shared Loader API 1 is required and not bundled. Mod Options Menu API 1,
version 3+ is optional for live settings. Without it, Auto Aim, Seeker Homing
Assist and Allow Multiplayer remain OFF. EN/KO ZIPs have identical runtime code.

한국어 요약: 멀티플레이 허용 토글은 기본 OFF다. 플레이어·식별된 몬스터 몸의
막힘·밀림 간격은 0.1cm(1mm)로 줄이고 벽·바닥 간격은 유지한다. 다리 사이를
넓게 막는 외곽 판정 대신 피해 판정 표면을 사용한다. 실제 피해 판정이 틈을
막으면 통과하지 못할 수 있으며, 멀티와 몸 회피의 실기 확인은 아직 필요하다.
