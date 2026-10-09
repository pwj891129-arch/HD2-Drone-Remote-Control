# Drone Remote Control 0.2.26 Private Test

Local test build. Not yet published or installed automatically.

## 한국어

- 일반 드론 진입 직후 `surface_hit_geometry_invalid`로 비행이 정지하는 실제 로그를 확인하고, 자기 캐릭터·배낭·무기를 접촉 좌표 검사 전에 제외하도록 수정.
- 식별된 다른 캐릭터의 몸은 넓은 이동/피해 충돌체가 아닌 게임 탄환 충돌용 필터를 사용. 몸 간격 **1cm**. 모델별 피격 부위·다리 틈의 실제 동작은 실기 검증 필요.
- 지형이나 몸 내부에서 시작한 거리 0 접촉은 바깥에서 반대로 조회. 같은 유닛·충돌체의 가까운 출구를 확인하면 부드럽게 탈출. 깊은 지형에서 출구를 확인하지 못하면 이동 보류.
- 벽·바닥 간격 배낭 1m / 씨커 0.5m, 씨커 진입 대기 0.5초, Q 폭파 제거, 멀티 기본 OFF 유지.
- 기존 ZIP을 제거·교체하고 적용한 뒤 게임을 재시작해야 새 소스가 실행됩니다. 설치 후 일반 드론의 자기 몸 끼임, 벽·바닥 씨커 진입, 몬스터 다리 사이를 확인해 주세요.

## English

- Exclude own character/equipment and broad movement hulls before validating contact geometry. Live 0.2.25 logs confirm repeated initial-overlap geometry failures holding Guard Dog flight.
- Use the native projectile collision filter for other identified character bodies, with **1cm** clearance. Exact model-specific limb gaps require live testing.
- Reverse probes recover a nearest verified exit face from zero-distance initial overlap. Smooth outward movement; no teleport, impulse or actor collision modifications. Unresolved solid interiors remain fail-closed.
- Preserve 1m Guard Dog / 0.5m Seeker terrain margins, 0.5s Seeker entry delay, removal of Q detonation and multiplayer default OFF.
- Normal sensor budget: at most 14 sweeps. Initial recovery: at most 28 sweeps. Sensor interval: 50ms.

Offline regression tests and read-only engine/filter checks do not verify live flight. Fully exit the game, replace the previous mod with one EN/KO ZIP, deploy and restart before testing.
