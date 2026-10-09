# 0.2.22 Private Test

## English

- Preserve Q/Quick Throw edge history across passive missing/unsupported Guard Dog reads.
- Wait up to 3 seconds for the actor's attached Seeker created by Quick Throw.
- Accept verified airborne states 3 and 4 with native motion active; a live read-only recording showed state 2 going directly to 4.
- Immediately release native AI/movement/pose overrides on detonation. Hide only meshes of the exact already-exploded unit; leave native damage, effects and destruction unchanged.
- Keep the camera/input hold at 0.7 seconds. Guard Dog control and equipped Q+Attack remain available, solo only.

Offline regression tests passed. In-game confirmation of this build is pending.
Completely exit, replace the previous mod, deploy with Bingus Shared Loader API 1 and restart.

## 한국어

- 가드 독 배낭이 없거나 다른 배낭을 사용할 때 Q+빠른 투척 입력 이력이 지워지던 문제 수정.
- 빠른 투척 동작 중 생성되는 본인 씨커를 최대 3초 기다림.
- 실제 기록에서 상태 2에서 4로 바로 넘어가는 것을 확인해 비행 상태 3·4와 자동 이동 활성화를 함께 검사.
- 폭발 직후 AI·이동·회전 제어 해제. 실제 폭발한 동일 씨커 외형만 숨기고 원래 피해·이펙트·파괴 처리 유지.
- 카메라·플레이어 입력만 0.7초 유지 후 복원. 배낭 드론·기존 Q+공격 방식 유지, 솔로 전용.

오프라인 회귀 검사 통과. 실제 수정판 확인은 필요하다.
게임을 완전히 종료한 뒤 기존 모드를 교체하고 Bingus Shared Loader API 1과 적용·재시작한다.
