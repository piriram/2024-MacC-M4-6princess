# 6princess 리팩토링 통합 장문 계획 (vLong 2026-02-21)

> 목적: 이번 세션에서 수행하려다 못한 작업 + 이미 정리해 둔 현재 진행 계획을 **한 문서에서 통합**한다.
> 범위: 카메라 촬영 플로우(요청/이미지 처리/전환/저장), 세션 안정성, 공통 에러 처리, 테스트/검증.

---

## 0) 현재 상태 요약 (한눈 정리)

### 완료된 배경 작업
- Phase 0~2차 진행 완료(일부)
  - 카메라 권한·세션 관련 구조 정리
  - `CameraManager`의 캡처를 Combine publisher(`takePicture() -> AnyPublisher<AVCapturePhoto, Error>`)로 전환
  - `CameraSessionService` Combine API 정식 적용(요청/시작/중단)
  - `session.startRunning()` 직접 호출 제거 및 경량 참조 카운트 기반 start/stop 정합성 강화
  - `FilterCollectionViewController`에서 셔터 직후 즉시 stop 호출 제거
  - 중복 촬영 진입 가드(`beginCapture`) 추가
  - 관련 유닛 테스트 누적 추가 및 통과

### 아직 남은 핵심 이슈
- 결과 화면 이동/저장 연계가 분리되어 있어 간헐적으로 `결과 화면 안 넘어감` 느낌이 남음
- 촬영 중복/경합은 완화되었으나, 상태기계 완결성이 부족
- 실기기 반복/동시성/백그라운드 경로 회귀 검증 미흡

---

## 1) 이번 세션까지의 실제 변경 이력(간단 로그)

### 완료 커밋
- `f52807b`: `Refactor: Combine 기반 Camera 촬영 파이프라인 정리`
- `7ee0351`: `Refactor: CameraSessionService Combine 스트림 통합`
- `8c60d0d`: `Fix: 촬영 직전 세션 즉시 stop으로 인한 캡처 실패 수정`
- `1851cff`: `Fix: 촬영 중복 호출로 인한 capture 에러 방지`

### 현재 분기 상태에서 핵심 코드 포인트
- `CameraViewModel.swift`
  - `CapturePipelineState`, `CapturePipelineError` 도입
  - `beginCapture()`, `resetCaptureState()`, `takePic()` 파이프라인 강화
  - 중복 처리 방지와 처리 중 상태 관리
- `FilterCollectionViewController.swift`
  - `shutterButtonTapped`에서 capture 게이트 사용
  - frame 미존재 시 캡처 상태 리셋
- `CameraView.swift`
  - onAppear/onDisappear에서 세션/캡처 상태 초기화 및 정리
- `CameraSessionService.swift`
  - 권한/세션 start-stop publisher + 레퍼런스 카운트
- 문서: `Refactor_Plan.md`에 미완료 작업 항목 기재됨

---

## 2) 미완료 작업(통합 우선순위) — 지금 해야 할 것

아래는 **아까 했던 계획 + 못한 계획**을 하나로 합친 최종 미완료 항목이다.

### P0. 캡처-전환-저장 파이프라인 일원화
**우선도: 최고**

#### 목표
현재 분산된 흐름을 하나의 state machine으로 통합한다.
- 현재: `takePic` 완료 -> `nextView=true` -> `IOView.onAppear`에서 저장 시도
- 목표: `takePhoto` 결과를 `CaptureResult.ready`로 통합 emit 후 뷰 전환/저장/에러 복구를 한 경로에서 처리

#### 해야 할 일
1. `CapturePipelineState` 확장
   - `idle, scheduled, capturing, processing, readyToNavigate, saving, completed, failed, cancelled` 추가
2. `nextView` 토글을 직접 바꾸지 않기
   - `CameraView`에서 `CameraViewModel`이 노출한 `routeToResult`(또는 `captureState == .readyToNavigate`)로만 전환
3. 결과물 생성 성공 시 `CaptureOutput` 객체를 상태 저장(또는 임시 저장 상태)하고,
   `IOView` 진입 전 최종 유효성 검사 후 이동
4. 저장 성공/실패 결과를 `CameraViewModel`로 다시 전달 받는 “single callback”로 설계

#### 완료 기준
- 결과 화면 전환이 1회만 발생
- 10회 연속 연타에서도 중복 이동 없음
- 저장 실패 시 사용자 메시지 노출 + 상태 복귀 가능

---

### P1. `nextView` 안정성 및 레이스 조건 정리
**우선도: 최고**

#### 목표
`nextView` 상태를 UI 레이스로부터 분리.

#### 해야 할 일
1. `CameraView` `navigationDestination`를 `isResultReady && !isTransitioning` 플래그로 변경
2. `FilterCollectionViewController`와 `frameManager.resultImage` 동기화를 검사하는 gate 추가
   - 프레임 미선택/미로딩 시 즉시 캡처 시작 차단
3. 캡처 완료 시점에 `nextView`를 직접 true로 만들지 말고 `captureState`를 통해 트리거
4. 디바이스 회전/온디맨드 재진입에서 `captureState`를 idempotent하게 reset

#### 완료 기준
- 간헐적으로 보고된 “결과 화면 안 넘어감” 증상 감소
- 실패 케이스에서 `nextView` 재세팅 불능 상태 없음

---

### P2. 셔터/상태 리셋 경로 통합
**우선도: 높음**

#### 목표
카메라 진입/탈출/실패/중단 경로를 한곳에서 관리

#### 해야 할 일
1. `CameraViewModel`에 아래 메서드 정리
   - `beginCapture()` : 진입 전 가드 + 이벤트 태그
   - `requestCapture(reason:)` : 실제 캡처 요청 실행 래퍼
   - `prepareForFailure(_:)` : 에러 메시지 + 상태 복귀
   - `resetCaptureState(reason:)` : onDisappear/권한취소/실패 경로 공통 사용
2. `FilterCollectionViewController`는 상태 갱신을 `requestCapture` 단 하나로 통일
3. `isTakePic`는 UI 표시 상태로만 제한하고 비즈니스 상태로는 사용 금지

#### 완료 기준
- 실패/백그라운드 진입 후 다시 진입해도 첫 탭에서 캡처 가능
- `beginCapture` 호출 실패 시 상태가 비정상 잔존하지 않음

---

### P3. 사용자 동작 경합 대응 테스트 보강 (CameraViewModel 중심)
**우선도: 중간~높음**

#### 목표
단위 테스트 범위를 서비스 단위를 넘어 UI 동작 경합까지 확장

#### 추가 테스트 시나리오
1. `DoubleTapShutterShouldTriggerSingleCapture`
2. `TimerCaptureSingleShotWhileQueued` (`delayTime` 변화)
3. `CaptureFailureShouldResetStateAndAllowRetry`
4. `AbortDuringProcessingShouldCancelAndRecover`
5. `RouteTransitionShouldEmitOnce`

#### 구현 방식
- `CameraManager` mock stub 주입
- `CameraSessionService` mock start/stop 카운터
- `XCTestExpectation`로 상태 전이 검증

#### 완료 기준
- 연속 탭 100회 시나리오에서 캡처는 100회 요청 대비 100회 처리 또는 규칙대로 스로틀
- 상태 전이 그래프 단위 검증 통과

---

### P4. 세션 레퍼런스 카운트와 UI 생명주기 결합 정리
**우선도: 중간**

#### 목표
`onAppear/onDisappear`에서 세션 참조가 꼬이지 않도록 카운트 안정화

#### 해야 할 일
1. `CameraView.onAppear`에서 `startCaptureSession` 호출은 idempotent
2. `onDisappear`에서 `endCaptureSession(force: false)` 형태 지원
3. `FilterCollectionViewController`에서는 뷰 계층과 무관하게 세션 stop 직접 호출 금지
4. 화면 이탈 시 `cameraManager.stopSession()` 호출 전 `captureState` 검사

#### 완료 기준
- 뷰 이동 시 session 카운트 과감소/증가 없음
- “session not running” 에러 로그 급감

---

### P5. 저장/앨범 저장 경로 일관성 및 사용자 피드백 정리
**우선도: 중간**

#### 목표
`IOView` 저장 경로도 동일한 에러/성공 규약으로 정리

#### 해야 할 일
1. 저장 실패 리턴값/에러를 `CameraViewModel`에게 알려 저장 결과를 상태로 반영
2. `IOView`는 pure UI로 전환하고 저장 실행 여부는 결과 데이터 전달 전 단계에서 결정
3. 권한 거부/디스크/앨범 생성 실패를 공통 alert 정책으로 정리

#### 완료 기준
- 저장 실패 시 안내가 항상 일관되고, 재시도 동작이 보장

---

### P6. 공통 에러/로깅 정책 통일
**우선도: 중간**

#### 목표
print 기반 분산 에러 대신 구조화된 에러로 정렬

#### 해야 할 일
1. `AppError` 카테고리 확장
   - 카메라 상태/권한/처리/저장
2. 화면 알림 메시지는 `showError(message:)` 단일 진입점 사용
3. 로그 태그 통일 (`[Camera]`, `[Capture]`, `[Storage]`)

#### 완료 기준
- 로깅으로 문제 재현 시 원인 추적 가능

---

### P7. 실기기/시뮬레이터 회귀 패키지 테스트
**우선도: 높음**

#### 목표
지금까지 단위테스트 PASS를 실사용 UX PASS로 끌어올림

#### 해야 할 일
1. 시나리오 실행표 작성
   - 무타이머 촬영 100회
   - 타이머 촬영 100회
   - 초당 연타(탭) 30회
   - 앱 백/포그라운드 전환 20회
   - 카메라 권한 거부/허용 토글
2. 실패/재시도/크래시 로그 수집
3. 빌드/테스트 결과를 문서에 누적

#### 완료 기준
- 반복 시나리오에서 크래시/중복 결과이동 없음
- 사용자 신고 이슈 빈도 감소(1회성 비정상 진입 제거)

---

## 3) 3주치 실행 플랜(장기 일정)

### 1주차 (현재~다음 3~5일)
- P0 + P1 구현(핵심 파이프라인 상태기계)
- P2의 가드/리셋 경로 정리 1차 완료
- 빌드/테스트 통과 + 문서 갱신

### 2주차
- P3 테스트 보강
- P4, P5 UI/세션/저장 경로 정합성 마무리
- P6 에러/로깅 통일 1차 적용
- 테스트/빌드 확인

### 3주차
- P7 실기기 회귀 패키지 실행
- 발견 이슈 핫픽스 및 결과 보고
- 최종 문서 및 커밋 스쿼시(또는 태스크별 PR 단위 정리)

---

## 4) 아카이브: 바로 체크할 실패 패턴

- `이미 촬영이 진행 중입니다`
- `세션이 실행중이지 않습니다`
- 결과 화면 이동 안됨(빈 화면/오래 대기)
- 저장 실패 후 뒤로 가기 동작 불안정
- 연타 후 `isTakenPhoto`가 복구되지 않음

각 항목별로 아래 템플릿으로 기록

- 발생 조건(타이머 유무/연타/기기상태)
- 재현 로그(`xcodebuild test`/실기기 로그)
- 상태 전이 로그(`captureState`, `sessionRunning`)
- 조치 후 상태 회복 확인

---

## 5) 지금 당장 반영할 DoD

1. 위 P0~P7를 `Task`로 전환해 각각 **체크박스 완료**
2. 각 Task 완료 시 커밋 메시지 규칙 준수:
   - `Refactor:` / `Fix:` / `Test:` prefix
3. 각 주차 종료시 `xcodebuild test + xcodebuild build` 결과를 문서 마지막에 기록
4. 작업 중 발견한 비정상 케이스는 `memory/2026-02-21.md`에 누적

---

## 6) 최종 체크리스트(문서용)

- [ ] P0 캡처-전환-저장 일원화 완료
- [ ] P1 nextView 안정성 완료
- [ ] P2 셔터/상태 리셋 경로 완료
- [ ] P3 경합 테스트 케이스 추가/통과
- [ ] P4 세션 레퍼런스-UI 생명주기 정합성 완료
- [ ] P5 저장 실패 복구 경로 완료
- [ ] P6 에러/로깅 정책 통일 완료
- [ ] P7 실기기/시뮬레이터 100회 회귀 검증 완료
- [ ] 문서 정리 및 커밋

---

참고: 기존의 **6princess 리팩토링 계획 문서(기초 구조)**는 이 문서 상단의 완료/미완료 맥락으로 자동 이관되며,
아래 통합 섹션(P0~P7)이 실행 기준(장문)로 최종 기준선이 된다.
