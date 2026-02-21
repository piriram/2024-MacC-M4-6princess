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

## 4) 릴리스 게이트
- 치명적 크래시 0건
- 저장 실패 재현률 임계치 이하
- 권한/로컬라이즈 경고 0건
- 핵심 플로우(촬영→편집→저장→공유) pass

## 5) 운영 규칙
- 카메라 하드웨어 의존 영역은 실기기 수동 검증 필수
- 로직/상태/영속성은 최대 자동화
- PR마다: 단위 테스트 + 빌드 + 수동 스모크 결과 첨부
