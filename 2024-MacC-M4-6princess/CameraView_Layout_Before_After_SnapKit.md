# 카메라 출력 위치 감사: SnapKit 전/후 비교

일시: 2026-03-02
범위: `CameraView.swift` (카메라 미리보기 영역)

## 1) 현재 상태 (SnapKit 적용 후)

현재 메인 브랜치에서 미리보기는 `CameraUIKitViewController` 내부에서 UIKit 뷰 3개를 고정 레이아웃으로 구성해 배치합니다.

- 컨테이너: `previewContainerView`
- 상단 바: `topContainerView`
- 하단 바: `bottomContainerView`
- 줌바: `zoomContainerView`

### 현재 배치 규칙
- `topContainerView`: `top=0, leading=0, trailing=0, height=46`
- `bottomContainerView`: `leading=0, trailing=0, bottom=0, height=111`(기본, 짧은 화면에서는 60으로 변경)
- `zoomContainerView`: `centerX`, `bottom = bottomContainerView.top - 20`
- `previewContainerView`: `top = topContainerView.bottom`, `centerX=super`
- `previewContainerView` 실제 크기:
  - `width = 화면폭`
  - `height = width * frameRatio`

### 위치 의미
- 카메라 출력은 상단 바 바로 아래 시작.
- 하단 바 위쪽 `zoomContainerView`에 의해 일부가 가려지지 않게 아래 여백이 분리됨.
- 미리보기 바닥/상단은 `width=screen width` 기준이라 수직 긴 화면에서 화면 가로 폭 전체를 사용.
- 결과적으로 **상단 46pt + 카메라 프리뷰(가로폭*ratio) + 하단 바(기본 111pt)** 구조입니다.

### 근거 코드
- `setupLayout()` 및 `updateLayoutForCurrentBounds()`:
  - `topContainerView`/`bottomContainerView`/`zoomContainerView` 제약: `/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Source/View/Camera/CameraView.swift:493`
  - `previewWidth = bounds.width`, `previewHeight = previewWidth * ratio`: `updateLayoutForCurrentBounds()` `586~597`
  - `bottomContainer` 높이 전환(111/60): `600`

## 2) SnapKit 리팩토링 이전 위치 (참고 이력)

`Refactor: CameraView를 UIKit+SnapKit 컨테이너 구조로 전환` 이전(`ae0b0ca` 부모 커밋)에는 SwiftUI 단일 뷰로 동작했습니다.

### 이전 위치 규칙
- `cameraPreview`는 `GeometryReader` 안에서 계산한 `geo.size.width` 기반.
- `isTall` 판별: `UIScreen.height / UIScreen.width > 2.0`
  - `true`이면:
    - `width = UIScreen.width`
    - `height = UIScreen.width * frameRatio`
  - `false`이면:
    - `width = (UIScreen.height - 200) / frameRatio`
    - `height = (UIScreen.height - 200)`
- 미리보기 상단은 ZStack 맨 위에 `Color.clear.frame(height:46)`로 여백 확보한 다음 바로 시작.
- 하단은 `VStack { CameraTopView; Spacer; CamZoomButtonView; CameraBottomView }` 구조로 오버레이.
- 즉, 화면 비율과 `height - 200` 계산식으로 하단 여백이 반영되는 방식이었음.

### 근거 코드
- 부모 커밋(`ae0b0ca^`)의 `CameraView.swift`:
  - `cameraPreview` 프레임 계산: `/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Source/View/Camera/CameraView.swift:23`~`34`
  - `isTall` 분기 프리뷰 크기: `78`~`99`

## 3) 비교 요약

| 항목 | SnapKit 이전(SwiftUI) | SnapKit 이후(Uikit+SnapKit) | 영향 |
|---|---|---|---|
| 기준 좌표 | `GeometryReader` 기반 동적 계산 (`geo`, `UIScreen`) | `view.bounds` 기반 제약 업데이트 | 계산 지점이 통합되어 일관성 개선 |
| 프리뷰 너비 | 기본 `UIScreen.width`, 다만 레거시 `isTall=false`일 때 `(height-200)/ratio` | 항상 `view.bounds.width` | 넓은 화면에서는 일관성↑, 짧은 화면에서는 이전 방식 대비 영역 차이 존재 |
| 프리뷰 높이 | `width*ratio` 또는 `height-200` 기반 계산 | `width*ratio`로 고정 | 세로 길이가 좁거나 노치/라운드 이슈일 때 UI 변동 최소화 |
| 상단/하단 간격 | `Color.clear` + Spacer 오버레이 | 고정 높이 top(46), bottom(111/60) 제약 | 레이아웃 의도 추정이 쉬워지고 회귀 테스트 포인트 명확 |

## 4) SnapKit 리팩토링 전 위치 유지 보장 포인트

Refactor 전후 비교에서 핵심은 **미리보기 시작 Y좌표**와 **하단 바의 충돌 방지**입니다.

- 시작 Y좌표: 전후 모두 상단 UI 높이만큼 오프셋 존재(전: 46pt clear spacer, 후: topContainer 하단)
- 하단 충돌: 전은 오버레이 구조, 후는 `bottomContainer` + `zoomContainerView`를 통해 제약으로 분리
- 결과적으로 “시각적 위치”는 매우 유사하되, **제약 기반 분리로 장치별 경계 처리 재현성은 개선**되었다고 볼 수 있음.

## 5) 다음 비교/검증 체크리스트 (SnapKit 리팩토링 전후 동등성)

1. 9:16·3:4·1:1 등 frameRatio 변경 시
   - 프리뷰 시작점 Y
   - 프리뷰 하단 끝점 Y
   - 하단 줌/버튼이 겹치지 않는지
2. tall/short 폰 비율 분기 시
   - `height / width > 2.0` 기준이 유지되는지
3. 프리뷰-결과물 파이프라인 연동
   - 미리보기 프레임(`previewContainerView.frame`)과 `viewModel.frameSize.size`가 일치하는지

## 6) SnapKit 전후 동등성 검증 체크리스트(실행형)

> 지금 바로 적용 가능한 회귀 체크리스트 + 수치 기준입니다. 우선순위: **P0 → P1 → P2**

### P0) 즉시 실행(수동 체크, 20분)
- [ ] iPhone tall (예: 393x852): `preview.top == topBar.bottom`
- [ ] iPhone short (SE급): `preview.height == screenWidth * frameRatio`
- [ ] 하단 바 높이: `bottom.height == 111`(short면 60)
- [ ] 줌바 여백: `zoom.bottom == bottom.top - 20`
- [ ] 촬영 진입/이탈 직후 `viewModel.frameSize.size == preview.size`

### P1) 반자동 로그 기반 검증(개발 빌드)
- [ ] 디버그 메뉴/콘솔에서 아래 로그 포맷이 일관되게 출력되는지
  - `[CameraLayout] bounds=(w,h) isTall=...`
  - `[CameraLayout] topH=..., bottomH=..., zoomBottom=...`
  - `[CameraLayout] preview=(x,y,w,h)`
  - `[CameraLayout] frameSize=(w,h)`
- [ ] tall/short 전환 시 `isTall`가 올바르게 바뀌는지
- [ ] 변경 전/후 비율(예: 3:4→1:1) 시 `preview.height/preview.width` 값이 목표 비율과 오차 ±1pt 이내인지

### P2) 장치군 매트릭스(실기기)
- [ ] iPhone mini/SE(짧음)
- [ ] iPhone standard(일반)
- [ ] iPhone max/plus(긴 화면)
- [ ] iPad
- [ ] 각 기기에서 `preview.y`, `bottom.y`, `bottom.height`, `zoom.y` 기록 → 동일 패턴 만족 여부 판정

## 7) 자동 비교 제안 (후속 구현)

- Accessibility ID를 붙이면 좌표 자동 수집이 가능해짐:
  - `previewContainerView.accessibilityIdentifier = "camera.preview"`
  - `topContainerView.accessibilityIdentifier = "camera.top"`
  - `bottomContainerView.accessibilityIdentifier = "camera.bottom"`
  - `zoomContainerView.accessibilityIdentifier = "camera.zoom"`

- 향후 UITest에서 `frame` 비교 자동화

```swift
func testCameraLayoutParity() throws {
    let app = XCUIApplication()
    app.launch()

    let preview = app.otherElements["camera.preview"]
    let top = app.otherElements["camera.top"]
    let bottom = app.otherElements["camera.bottom"]
    let zoom = app.otherElements["camera.zoom"]

    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertTrue(top.exists && bottom.exists && zoom.exists)

    let p = preview.frame
    let t = top.frame
    let b = bottom.frame
    let z = zoom.frame

    XCTAssertLessThanOrEqual(abs(p.minY - t.maxY), 2)
    XCTAssertLessThanOrEqual(abs(p.height - (p.width * (4.0/3.0))), 2)
    XCTAssertLessThanOrEqual(abs(z.maxY - (b.minY - 20)), 2)
}
```

- 실제 기기/시뮬레이터별 스크린샷 기반 diff는 별도 QA 산출물에 캡처 권장

---

### 참고 커밋
- `ae0b0ca`: `Refactor: CameraView를 UIKit+SnapKit 컨테이너 구조로 전환`
- `f766394`: `Refactor: Camera 상하단/줌 UI를 UIKit+SnapKit으로 전환`
- `8afd487`: `Fix: 카메라 프리뷰 가로 풀폭 레이아웃 복원`
### 적용 반영(현재 브랜치)

현재 브랜치에서 동등성 검증을 바로 수행할 수 있도록 아래 런타임 포인트를 선적용함:
- `CameraView.swift`
  - `preview/top/bottom/zoom` 컨테이너에 Accessibility Identifier 부여
    - `camera.preview`
    - `camera.top`
    - `camera.bottom`
    - `camera.zoom`
  - `DEBUG` 빌드에서 레이아웃 로그 출력 추가
    - `[CameraLayout] bounds=...`
    - `[CameraLayout] topH=... bottomH=...`
    - `[CameraLayout] preview=...`
    - `[CameraLayout] frameSize=...`
- 위 로그/ID는 다음 단계로 작성할 예정인 UITest에서 좌표 자동 수집용 seed 데이터로 사용 가능

### 실행 반영: UITest 추가됨

요건(동일성 검사)의 시작점으로 아래 테스트가 추가됨:
- `2024-MacC-M4-6princessUITests/SmokeLaunchUITests.swift`
  - `testCameraLayoutParity_PreSnapKitRefactor`
  - 액세스: `camera.preview / camera.top / camera.bottom / camera.zoom`
  - 검사 항목:
    - `preview.top == top.bottom` (정렬)
    - `preview.width == window.width`
    - `bottom.height == 111` or `60` (tall/short 기준)
    - `zoom.bottom == bottom.top - 20`
    - `preview.ratio in {1:1, 3:4, 9:16}`
    - 콘솔 로그 출력으로 회귀 추적 가시화

## 2026-03-02 추가 업데이트 (운영 반영 의견)

### 현 운영 합의
- **가로폭**: 아이폰은 무조건 full-width로 유지.
- **기기별 이슈**: 작은 폰은 top+bottom 고정치가 고정되면서 유효 화면이 모자라는 증상이 발생할 수 있어 **상단 침범 옵션** 필요.

### 적용된 디버그 옵션
- `debug.camera.preview.topPlacement` (`RuntimeTestingOptions`)
- 값:
  - `respectTopBar`: 기존 위치(`preview.top = top.bottom`)
  - `overlapTopBar`: `preview.top = top.bottom - 46`
- 선택 위치: 디버그 화면 `Camera Debug > Camera Preview > Top Bar Placement`

### 다음 구현 후보
- `smallPhone` 자동 판별 기준 추가(예: 디바이스 높이/폭 또는 aspect 기반)
- 가용 높이 계산을 통해 preview 높이 클램프:
  - `availableHeight = bounds.height - topOffset - bottomHeight - safeArea`
  - `previewHeight = min(width * frameRatio, availableHeight)`
- 필요 시 bottom 영역도 동적 축소해 줌/버튼 가용 공간 보존

### 체크포인트 업데이트 제안
- 기존 체크리스트(P0~P2)에 아래 항목 추가:
  - smallPhone에서 `preview.top`이 topBar를 침범 가능한지, 그리고 침범 없이도 유효 높이 확보 가능한지 판정
  - 침범 모드일 때 `preview.width == window.width` 유지 여부
  - 침범 모드일 때 하단 오버랩/터치 오동작 없이 `zoom`/`bottom` 가시성 유지
