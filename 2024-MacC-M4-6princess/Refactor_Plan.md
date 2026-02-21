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

## 2-4. 이번 회차(2026-02-21) 실행: 카메라 Capture 흐름 Combine화

### 적용 범위
- 대상: `CameraManager`, `CameraViewModel`, `CameraTimerSecondsView`
- 목적: `AVCapturePhotoCaptureDelegate`의 콜백 기반 촬영 처리를 Combine 이벤트 기반으로 정리하여 테스트 용이성/취소 제어/오류 전달 개선

### 변경 내용
1. **CameraManager**
   - `takePicture()` 시그니처를 `()-> AnyPublisher<AVCapturePhoto, Error>`로 변경
   - 내부적으로 `PassthroughSubject`를 생성해 `didFinishProcessingPhoto` 결과를 스트림으로 전달
   - 카메라 세션 미실행/중복 촬영 요청 시 `CaptureError`(`sessionNotRunning`, `captureAlreadyInProgress`) 실패로 종료
   - 무음 샷 동작(`AudioServicesDisposeSystemSoundID(1108)`)을 `CameraManager` 내부 delegate 훅으로 이동

2. **CameraViewModel**
   - `takePic()`에서 delegate 직접 전달 방식 제거
   - `Combine` 체인으로 지연(0/0.5초) + 촬영 요청 + 완료/실패 처리 연결
   - 기존 이미지 처리 로직(미러링/회전/크롭)을 `handleCapturedPhoto(_:)`로 분리해 가독성 정리
   - 실패 시 `showErrorAlert` 연동 메시지 출력 강화

3. **CameraTimerSecondsView**
   - 타이머 시작 조건을 `delayTime > 0`로 가드
   - `delayTime == 0`에서 분모 0 분할 잠재 오류 방지

### 바로 다음 검증 항목
- [ ] `xcodebuild` 테스트 실행 (전체 테스트 스위트)
- [ ] 카메라 촬영 플로우 회귀 확인: 셔터 버튼 탭 시 0초/지연 촬영 모두 동작
- [ ] 권한 미승인/세션 미시작 상태에서 오류 알림 노출 동작 점검
- [ ] 빌드 경고/린트 에러 추가 점검

### 실행 결과 (2026-02-21 회차)
- [x] `xcodebuild test` 통과 (모든 테스트)
- [x] `xcodebuild build` 통과
- [x] 코드 변경: `CameraManager`/`CameraViewModel`/`CameraTimerSecondsView`
- [x] 커밋: `c806e78` (`Refactor: Combine 기반 Camera 촬영 파이프라인 정리`)
