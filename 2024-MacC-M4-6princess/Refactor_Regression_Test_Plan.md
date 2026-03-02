# Frameet 리팩토링 회귀 테스트 플랜

## 1) 자동화 대상 (XCTest)

### A. 순수 로직 단위 테스트
- `NavigationManager`
  - `pop()` 빈 스택 안전성
  - `pop(depth:)` 범위 초과 방어
  - `popToRoot()` 동작 검증
- `CameraViewModel`
  - 줌 값 clamp
  - `cropToAspectRatio` 경계/비율 보정
  - front camera 변환 nil 경로
- `DFEditViewModel` / `DFModifyViewModel`
  - 마스크 합성 nil 분기
  - 히스토리 index 경계
  - undo/redo 시 상태 일관성
- `IOViewModel`
  - 저장 파이프라인 단계별 실패 분기
  - 재시도 루프 동작

### B. 영속성 테스트
- `PersistenceController(inMemory: true)` 기반 CRUD
- 저장소 로드 실패 시 앱 중단 없이 처리되는지 검증

## 2) 반자동화 대상 (시뮬레이터)
- 권한 denied/limited 상태에서 저장/카메라 진입 동작
- 카메라 화면 진입/이탈 반복 시 세션 start/stop 호출 일관성
- 비카메라 화면 네비게이션 스모크 테스트

## 3) 수동 필수 테스트 (실기기)

### 디바이스 매트릭스
- iPhone 1종(최신) + iPhone 1종(구형)
- iPad 1종

### 시나리오
1. 첫 실행 권한 플로우(카메라/사진)
2. 촬영 → 편집 → 저장 → 공유 전체 플로우
3. 전면/후면 카메라 전환 + 타이머 촬영
4. 프레임 오버레이 정합성(기기별 비율)
5. 빠른 왕복 네비게이션(카메라↔편집↔결과)
6. 저조도/연속 촬영 안정성
7. 백그라운드 전환 후 복귀
8. **카메라 미리보기 위치 회귀 체크**: `CameraView_Layout_Before_After_SnapKit.md`의 P0~P2 체크리스트 준수
   - 높이/폭/간격 수치 확인
   - top/preview/bottom/zoom 좌표 추적
   - tall/short 분기 검증


## 4) 릴리스 게이트
- 치명적 크래시 0건
- 저장 실패 재현률 임계치 이하
- 권한/로컬라이즈 경고 0건
- 핵심 플로우(촬영→편집→저장→공유) pass

## 5) 운영 규칙
- 카메라 하드웨어 의존 영역은 실기기 수동 검증 필수
- 로직/상태/영속성은 최대 자동화
- PR마다: 단위 테스트 + 빌드 + 수동 스모크 결과 첨부

## 2026-03-02 런타임 정책 업데이트

### 카메라 레이아웃 정책(즉시 합의)
- **아이폰 우선 정책:** 가로는 항상 화면 전체(`bounds.width`)를 사용.
- 작은 폰(높이/폭이 상대적으로 작은 iPhone)에서 공간이 부족할 때는 위/아래 침범 허용이 필요한 것으로 판단.
- 상단 침범 정책은 현재 디버그 옵션 기반으로 제어:
  - `Respect Top Bar`(기본): `preview.top = top.bottom`
  - `Overlap Top Bar`: `preview.top = top.bottom - 46`
- 기기별 자동 정책은 아직 미정의 단계였으나, 향후 다음 액션으로 `smallPhone` 자동 판별 및 bottom 높이 동적 축소 적용을 고려.

### 지금까지 반영한 실행 단서
- 런타임 설정 확장
  - `RuntimeTestingOptions`에 `debug.camera.preview.topPlacement` 키 추가
  - `PreviewTopPlacementOption` (`respectTopBar`, `overlapTopBar`) 추가
  - `CameraDebugOptionsView`에 UI Picker(`Camera Preview > Top Bar Placement`) 추가
  - `CameraView.updateLayoutForCurrentBounds()`에서 top 오프셋 전환 반영
- `testCameraLayoutParity_PreSnapKitRefactor`는 iPhone 기준 통과(짧은/긴 분기 포함)된 바 있으며, iPad 안정성은 추가 보정 필요 상태.

### 문서 반영 계획(다음)
- `CameraView_Layout_Before_After_SnapKit.md`에 "작은 폰 가용 높이 기반 클램프" 항목과 smallPhone 우선 전략을 체크리스트로 추가
- 운영 규칙: 위 배치 변화는 `Refactor Regression Test Plan`의 회귀 체크포인트(P0~P2)에 반영 후 배포.
