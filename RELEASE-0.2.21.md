## 드론 원격조종 0.2.21 시험판

- **Q(조준 모드 전환)를 누른 채 G(빠른 투척)**로 씨커 조종을 준비합니다. 키는 게임 설정에서 읽으며 4번으로 들 필요가 없습니다. 기존 Q+공격 방식도 유지합니다.
- Q를 먼저 누른 동안 본인 인벤토리의 붙어 있는 씨커를 보관해, 빠른 투척 직후에도 동일 객체만 추적합니다. 객체 생성이 늦으면 최대 1초 기다리며 근처 드론을 임의로 연결하거나 투척 입력을 대신 보내지 않습니다.
- 폭발 요청 또는 원래 폭발 상태 확인 후 마지막 카메라 위치·각도를 **0.7초 유지**한 뒤 플레이어 시점·입력을 복원합니다. 유지 중 파괴된 드론을 다시 판독·조종하거나 추가 폭발을 요청하지 않습니다.
- 카메라 요청 행이 바뀌어도 같은 시점을 유지합니다. 포커스 상실, 파티원 합류, 소유자·카메라·키 설정 변경과 종료 시에는 지연을 중단하고 바로 복원을 시도합니다.
- 가드 독 배낭 조종과 기존 과열·탄 소진 복귀는 유지합니다. 양쪽 모두 솔로 전용입니다.

EN / KO 중 하나만 적용하세요. 게임을 완전히 종료하고 Arsenal에서 이전 드론 모드를 교체한 뒤 옵션을 켜고 Deploy / 재시작합니다. **Bingus Shared Loader / API 1은 필수이며 별도 설치**입니다. Mod Options Menu는 배낭 자동조준용 선택 의존성입니다.

오프라인 회귀 검사와 패키지 검증은 통과했습니다. 실행 중인 게임에서 빠른 투척 액션의 G 키 값을 읽기 전용으로 확인했습니다. **실제 Q+G 조종 진입과 폭발 장면 유지 타이밍은 적용 후 인게임 검증이 필요합니다.** 안정판이 아니며 기존 정밀 조준·사격 이펙트 및 네이티브 호출 안정성의 한계가 남아 있습니다. 자동 설치나 게임 메모리 쓰기는 하지 않았습니다.

## Drone Remote Control 0.2.21 Test Build

Adds mapped Aim Mode Switch + Quick Throw (currently Q+G) for Seekers without
equipping slot 4. Keeps the equipped Q+Attack route. The exact owned inventory
item is cached while Q is held before G; immediate native detach retains that
ticket. Delayed item creation waits at most 1 second. No nearby-unit adoption
or synthetic throw input is used.

After requested or observed detonation, freezes the last camera pose for 0.7
seconds before restoring player view/input. Destroyed-drone data is not accessed
during the hold, including camera-row handoffs. Focus loss, party join, changed
actor/camera/bindings or shutdown interrupt the hold safely. Backpack control and
its immediate ammo/heat return remain unchanged. Both modes remain solo only.

Install one EN/KO ZIP with the game closed, replace the previous version, enable
the option, Deploy, and restart. Bingus Shared Loader / API 1 is required and
not bundled; Mod Options Menu is optional for backpack Auto Aim.

Offline regressions and package checks passed; the live Quick Throw key payload
was checked read-only. Actual Q+G takeover and explosion-view timing still need
in-game testing. This is not a stable release. Existing crosshair/effect and
native-call stability limitations remain. No automatic installation, game
writes or native game calls were performed during validation.
