# 6princess 리팩토링 계획 문서

## 1) 배경
현재 `refactor/try-refactor` 브랜치에서 Phase 1(안전성/소유권 정리) 작업을 완료했으며,
이제 Phase 2를 진행해 기능 회귀를 최소화하면서 유지보수성을 높인다.

- 완료된 주요 선행 작업
  - App/Ctor 환경 객체 소유권 정리
  - Camera/DFEdit/DFModify 크래시 후보 포인트 방어 처리
  - iOS 빌드 경고 정리
  - 권한 안내문 다국어 `InfoPlist.strings` 정합성 확보 (`de` 포함)
  - 새 파일 헤더 주석 없는 방식 적용

---

## 2) 현재 상태 점검(요약)

### 완료됨 (Done)
- `CameraViewModel`의 강제 언랩(옵셔널) 다수 완화
- `CameraManager` 세션 종료 조건 수정
- `DFEditView` 렌더 처리의 nil-안전성 강화
- `DFEditViewModel`에 `CIImage?`, `UIImage?` 반환 기반 실패 경로 추가
- `DFModifyViewModel` 히스토리 갱신 경계 개선
- 권한 문자열: `InfoPlist.strings` 다국어 정리 완료
  - 지원 언어: `ar, de, en, ja, ko, zh-Hans, zh-Hant`
- `.pbxproj`에서 하드코딩 권한 문자열 제거

### 아직 필요한 항목
- 중복 상태 생성/전역 의존성 재검토
- 코어 로직/유틸 분리 부족
- 에러 처리 일관성 미흡(로그/알림 경로 통합 필요)
- 테스트/회귀 체크리스트 미완

---

## 3) 다음 단계: Phase 2 작업 계획

### 2-1. 구조 정리 및 안정성 강화 (우선순위 높은 항목)

#### A. 상태/의존성 정리
- `EnvironmentObject` 주입 지점 재점검
- 뷰에서 `@StateObject`/`@ObservedObject` 중복 생성 제거
- 전역적으로 사용되는 모델(예: `FrameManager`, `NavigationManager`, `ImageListModel`)의 소유권 경계 고정

#### B. 핵심 크래시 후보 라인 리팩토링
- `ImageRenderer`/`CIContext` 렌더 실패시 사용자 플로우 분기 강화
- `DFEdit`/`DFModify` 편집 히스토리 경계 검증 통합
- 카메라 세션 start/stop 호출 횟수 및 중복 방지

#### C. 에러 처리 통일
- UI 경고/로그 처리 방식 공통화
- “print만 남기는” 패턴 제거, 실패 시 사용자에게 피드백 가능하도록 정리

### 2-2. 도메인 분리 (중간 우선순위)

- `ImagePipelineService` (크롭/필터/렌더)
- `PersistenceService` (CoreData 저장/조회/삭제)
- `CameraSessionService` (세션 구성/시작/종료)

> 목표: ViewModel은 화면 상태 유지 중심, 무거운 비즈니스 로직은 서비스로 이동.

### 2-3. 상수/유틸 통일
- 매직넘버/중복 산식 정리
  - 크롭 비율, 확대/축소 경계, 오프셋 계산, 기본 스케일
- `ScaleHelper`/`ImageMathUtil` 같은 공통 유틸 생성

---

## 4) 검증 기준 (Definition of Done)

### 기능
- 촬영 → 편집 → 저장 → 목록 관리 플로우 동작
- iPad/iPhone 회전/뷰 레이아웃에서 주요 동작 정상

### 안정성
- 빌드 경고 중 권한/설정 관련 경고 미출력
- 기존 동작(카메라 촬영, 필터, 저장)에 대한 수동 회귀 확인

### 코드 품질
- 강제 언랩(`!`) 감축 및 nil-안전 가드 강화
- 책임 분리 문서화(서비스/VM/뷰 경계)

---

## 5) 실행 순서(권장)

1. **이번 주**
   - 상태 소유권 정리 + 크래시 후보 정리
   - 에러 처리 통일
2. **다음 주**
   - 서비스 레이어 초기 분리
   - 공통 유틸 추출
3. **마지막 단계**
   - 회귀 테스트, 빌드 정리, 문서 보강

---

## 6) 운영 규칙(지시 반영)
- 새로 생성되는 문자열/설정 파일에는 상단 헤더 주석 추가하지 않음
- 다국어 문자열은 각 `.lproj/InfoPlist.strings`에 통합 관리
- 핵심 설정 변경 전/후 빌드 확인 로그를 남김
