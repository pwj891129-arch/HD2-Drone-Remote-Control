# Drone Remote Control 0.2.25 Private Test

## 한국어

- 씨커 조종 진입 대기: 1초에서 **0.5초**로 단축.
- 조종 중 **Q 폭파 제거**. 공격키 폭파·30초 제한시간·원래 게임의 폭발은 유지.
- 같은 소유자·씨커·세대의 검증된 데이터 저장 위치 변경은 연결을 갱신. 다른 개체·알 수 없는 값·유효한 중복 저장 위치는 거부.
- 취소 사유와 조종 시간을 이벤트마다 즉시 저장. 이전 실행 로그가 비어 있어 임의 취소의 실제 원인은 아직 확정되지 않음.
- 플레이어·식별된 몬스터의 몸 막힘 판정 **임시 OFF**. 다리 틈뿐 아니라 몸통도 통과할 수 있음. 부위별 정밀 회피는 미구현.
- 벽·바닥 거리 유지: 배낭 1m, 씨커 0.5m. 멀티 허용 기본 OFF 유지.

게임을 완전히 종료하고 기존 모드를 ZIP 한 개로 교체·적용한 뒤 재시작하세요.
Bingus Shared Loader API 1 필요. Mod Options Menu API 1/버전 3 이상은 인게임 옵션용으로 선택 사항입니다.
오프라인 회귀·패키지 검증 대상 시험판이며, 실기에서 임의 취소·몸 통과와 멀티 동작 확인이 필요합니다.

## English

- Seeker takeover settling delay reduced from 1s to **0.5s**.
- **Q no longer detonates during control**. Fresh Attack, the 30s lifetime and native explosions remain.
- Verified storage relocation of the exact owned Seeker renews control. Foreign identities, unrecognized values and duplicate still-live storage fail closed.
- Event logs are appended and closed immediately, with cancellation reason and control duration. The reported random cancellation cause is not confirmed because the prior live log was empty.
- Player/identified enemy **body blocking temporarily OFF**. Bodies can be traversed as well as leg gaps; per-limb avoidance is not implemented.
- Wall/floor margins remain 1m for backpacks and 0.5m for Seekers. Multiplayer defaults OFF.

Fully exit the game, replace the previous mod with one ZIP, deploy and restart.
Requires Bingus Shared Loader API 1; Mod Options Menu API 1/version 3+ is optional for in-game settings.
This is an offline-tested private prototype. Live cancellation, body passage and multiplayer behavior require verification.
