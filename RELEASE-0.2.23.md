# Drone Remote Control 0.2.23-test

Experimental solo-only prototype. New behavior has passed offline regression
tests, not live gameplay validation. Bingus Shared Loader API 1 is required and
not bundled. Mod Options Menu API 1/version 3+ enables the optional toggles.

## Changes

- Wait 1 second of continuous native Seeker deployment before camera/control
  takeover; interrupt the wait safely on focus loss, party join or detonation.
- Include registered damage-body shape queries alongside geometry sensing,
  including the owner's body. Bounded 50ms sensing, at most 14 private sweeps;
  no physical collision mutation, entity-list scan or teleport.
- Add independent in-game Seeker Homing Assist, default OFF. ON reads verified
  native targets, but manual movement/mouse input takes priority. Assisted
  flight uses existing inertia and clearance; native Boids flight stays paused.
- Renew capture only for known original-state resets on the exact owned
  Seeker. Unknown states still fail closed. Show homing mode in the HUD.
- Retain Q+Quick Throw, equipped Q+Attack, 30-second lifetime, no Seeker range
  limit and 0.7-second post-explosion view.

Actual player/enemy body hits and homing transitions need in-game confirmation.
The settling delay does not guarantee escape from deeply embedded geometry.
Replace the old package with one EN/KO ZIP, deploy and fully restart.

## 한국어

- 실제 전개 상태가 연속 1초 유지된 뒤 씨커 조종에 진입합니다.
- 벽·바닥뿐 아니라 플레이어·적의 몸 표면을 회피하도록 조회를 확장했습니다.
- 인게임 `씨커 유도 보조`를 추가했습니다. 기본 OFF이며 ON에서도 수동 입력이 우선합니다.
- 동일 씨커의 알려진 AI 초기화는 제어권을 재확보하고, 알 수 없는 상태는 안전 종료합니다.
- 몸 표면 회피와 유도 전환은 실제 게임 확인이 필요합니다. 벽에 깊이 박힌 씨커의 강제 탈출 기능은 아닙니다.
- 게임을 완전히 종료하고 새 ZIP 한 개로 교체·적용·재시작하세요.
