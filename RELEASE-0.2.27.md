# Drone Remote Control 0.2.27-test

Experimental prerelease, not a stable release. No automatic installation.

Requires Bingus Shared Loader API 1 (not bundled). Mod Options Menu API 1,
version 3+ is optional for in-game settings. Use one EN or KO ZIP, not both.
Without the options menu, auto aim, Seeker homing and multiplayer stay OFF.

## 한국어

0.2.22 이후 누적 변경에는 인게임 씨커 유도 보조·멀티 허용 옵션(모두 기본 OFF), 씨커 진입 대기 0.5초, Q 폭파 제거, 동일 소유 씨커의 검증된 데이터 위치 변경 대응, 즉시 저장되는 취소 사유 로그가 포함됩니다. 멀티의 권한 문제를 해결하거나 임의 취소가 완전히 사라졌다고 보장하는 버전은 아닙니다.

- K-9 정보창에 실제 아크 무기의 발사 준비율, 진행 막대, 남은 대기시간을 추가했습니다. 발사 간격은 게임의 현재 무기값을 사용합니다. 공격 버튼 유지시간으로 추정하는 게이지가 아닙니다.
- 준비값을 읽을 수 없으면 `--`로 표시하며, 이 표시 오류 때문에 조종까지 중단하지 않습니다.
- 타이탄의 부위별 피해 목록과 실제 충돌체 이름을 비교해 넓은 별도 몸 충돌체를 제외합니다. 몸 간격은 1cm이며 실제 모델과 피격 형상이 완전히 같다는 보장은 아닙니다.
- 여러 접촉을 조회하므로 제외된 큰 충돌체 뒤의 실제 부위와 벽도 확인합니다. 움직이는 몸에 이미 겹쳤다면 해당 몸에서 빠져나가는 동안만 몸 접촉을 제외합니다. 지형 판정은 유지합니다.
- 지형 내부에서 시작한 씨커는 역방향 출구 조회와 유효한 침투 깊이로 복구를 시도합니다. 출구가 불명확한 깊은 내부는 보류하며, 조회 횟수 상한은 유지했습니다.
- 멀티 기본 OFF, 씨커 진입 대기 0.5초, 공격 입력 폭파, Q 폭파 없음, 배낭 1m·씨커 0.5m 지형 간격은 유지합니다.

게임 종료 후 기존 모드를 이 ZIP 한 개로 교체하고 Arsenal 적용 후 재시작하세요.
자동 회귀 검사는 통과했습니다. 새 판의 K-9 실제 발사 진행 표시, 타이탄 다리 틈 통과, 벽 내부 탈출은 실기 검증이 필요합니다.

## English

Since the last public 0.2.22 release: optional in-game Seeker Homing Assist
and Allow Multiplayer (both default OFF), 0.5 s Seeker entry settling, no Q
detonation during control, validated same-owner storage relocation handling,
and immediately persisted cancellation logs. Multiplayer authority and all
reported random cancellation causes are not resolved or guaranteed.

- K-9 HUD shows actual next-shot Arc readiness, a progress bar and remaining wait. The interval comes from the current weapon instance, not a hardcoded timer or attack-button duration. Optional read failures show `--` without disabling control.
- Character contacts must match actors explicitly listed in Health named damage zones. Bounded all-hit sweeps discard broad hulls without masking real parts or terrain behind them. Body clearance remains 1 cm.
- An enveloping moving body temporarily allows escape from that body only. Terrain clearance stays active.
- Solid initial overlap attempts a verified reverse exit or a bounded penetration-depth plane with a validated outward normal. Unverified deep interiors still hold flight. Sensor rate 50 ms; at most 14 normal + 14 recovery sweeps, 32 output hits per sweep.
- Existing default-solo policy, Seeker entry delay, controls and terrain margins are preserved.

Offline regression checks passed. New HUD and live flight behavior remain unverified. Replace the old mod, deploy and fully restart.

## Evidence

`research/native-body-arc-20261009.json` records the read-only K-9 idle timer, Titan actor membership and retained native code sites. No native function or process write was used for those inspections. Runtime surface queries still invoke the guarded native worker after deployment.

Negative sweep depth can represent initial-overlap penetration; the recovery does not use an undefined zero-distance contact position. See [PhysX PxSweepHit documentation](https://nvidia-omniverse.github.io/PhysX/physx/5.3.1/_api_build/struct_px_sweep_hit.html). Every recovered plane still requires bounded depth and a valid normal or matching UnitRef/ActorRef reverse exit.
