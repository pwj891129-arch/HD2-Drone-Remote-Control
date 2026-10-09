## 드론 원격조종 0.2.20 시험판

헬퍼와 별도로 배포하는 **솔로 전용 프로토타입**입니다. 안정판이 아닙니다.

- 가드 독, 로버, 핫 독, K-9, 독 브레스 배낭 5종의 조종 경로를 포함합니다.
- G-50 씨커와 G-60 대전차 씨커 조종을 추가했습니다. 투척무기 들기 키로 손에 든 뒤, 조준 모드 전환 키를 누른 채 공격키를 누르고 **놓아** 직접 던집니다. 손에서 떨어져 전개된 동일 객체만 조종합니다.
- 씨커 조종 중 공격키 또는 조준 모드 전환 키를 새로 누르거나, 전개 확인 후 30초가 지나면 원본 폭발 처리를 요청합니다. 복귀·거리 제한·추가 충돌 폭발은 없습니다.
- 배낭 드론은 100m 거리 제한과 탄 소진·과열 시 원래 AI로 복귀하는 동작을 유지합니다.
- 비물리 표면 이격은 배낭 1m, 씨커 0.5m입니다. 복잡한 지형 전체에서의 동작은 아직 검증되지 않았습니다.
- 두 종류 모두 파티원이 없는 상태에서만 작동하며 합류 시 조종을 종료합니다. 다른 플레이어의 드론을 연결하지 않습니다.

### 설치

EN / KO 중 **하나만** 받으세요. 실행 코드는 같으며 Arsenal 설명 언어만 다릅니다.
게임을 완전히 종료하고 Arsenal에서 이전 드론 모드를 교체한 뒤 조종 옵션을 켜고 Deploy / 재시작하세요.
**Bingus Shared Loader / API 1은 필수**이며 포함되지 않습니다. Mod Options Menu는 배낭 자동조준 설정용 선택 의존성입니다. 없으면 수동 조준 기본값으로 작동합니다.
헬퍼, HUD+, 차량 조종 모드는 필수가 아닙니다.

### 검증 상태

오프라인 LuaJIT·합성 메모리·입력/종료 복원·패키지 검사를 통과했습니다.
일반 가드 독과 G-60의 연결·코드 가드를 실제 게임에서 읽기 전용으로 확인했지만,
**새 씨커 카메라 전환·이동·폭발과 추가 가드 독 종류의 실제 조종은 시험 전**입니다.
네이티브 호출의 충돌 가능성과 정밀 조준점·사격 이펙트의 한계가 남아 있습니다.
게임 메모리 캡처, 게임 바이너리, 다른 모드 및 개인 조사 파일은 공개하지 않습니다.

## Drone Remote Control 0.2.20 Prerelease

**Solo-only experimental prototype, not a stable release.**

Includes control paths for five Guard Dog backpack families and adds G-50/G-60
Seeker takeover after the game's native throw on Attack release. Equip slot 4,
hold Aim Mode Switch, press Attack, then release it. Only the same owned deployed
entity can be controlled. Fresh Attack or Aim Mode Switch, or a 30-second timeout,
requests the original explosion. Seekers have no return or range limit.

Backpacks retain the 100 m signal limit and native-AI return on empty ammunition
or full overheat. Approximate nonphysical clearance is 1 m for backpacks and
0.5 m for Seekers. Both modes exit on a party join.

Install only one EN/KO ZIP with the game closed, enable its Arsenal option,
Deploy, and restart. Both have the same runtime. **Bingus Shared Loader / API 1
is required and not bundled.** Mod Options Menu is optional for backpack Auto
Aim, which defaults to manual aim. HD2 Helper, HUD+ and vehicle-control mods are
not required.

Offline regressions and package checks passed. Guard Dog and held G-60
connections/code guards were checked read-only. **Actual new Seeker control,
detonation, additional backpack-family control and native-call stability still
need in-game testing.** Crosshair/effect alignment remains incomplete. No game
binaries, memory captures or other mods are included. SHA-256 files accompany
both packages.
