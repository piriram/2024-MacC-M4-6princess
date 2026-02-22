# Branch Status & Decision Log

이 파일은 실험 브랜치가 많아질 때 `무엇을 선택했고`, `무엇을 버렸는지`를 빠르게 확인하기 위한 단일 기준 문서다.

## 현재 결정 (2026-02-23)

| Topic | Branch | Commit | Build | Status | Reason |
|---|---|---:|---:|---|---|
| Camera startup latency | `Feat/camera-session-option2` | `ad3e327` | `202602230` | `SELECTED` | 내부 전환 지연 개선 + 릴리즈 리스크가 상대적으로 낮았다. |
| Camera startup latency | `Feat/camera-session-option3` | `3434f77` | `202602231` | `REJECTED` | QA에서 실패(사용자 보고: "옵션3은 터짐"). 구조 변경 범위가 커서 회귀 가능성이 높았다. |
| FrameView UI split | `feat/frameview-ui-wip` | `93580e5` | `202602229` | `WIP` | UI 작업 전용 분리 브랜치로 유지 중이다. |

---

## 헷갈림 방지 운영 규칙

1. 실험 시작 시 반드시 이 파일에 `1줄` 추가한다.
2. 상태 값은 `WIP`, `SELECTED`, `REJECTED`, `MERGED` 네 가지만 사용한다.
3. 실패 브랜치는 닫지 말고 `REJECTED` 이유를 한 줄로 남긴다.
4. 최종 선택 후에는 선택 브랜치만 머지하고, 나머지는 `REJECTED`로 고정한다.
5. 릴리즈에 사용한 커밋/빌드는 반드시 같이 적는다.

---

## 새 실험 추가 템플릿

| Topic | Branch | Commit | Build | Status | Reason |
|---|---:|---:|---:|---|---|
| 예: Camera startup latency | `feat/...` | `abc1234` | `2026....` | `WIP` | 무엇을 검증 중인지 한 줄 |
