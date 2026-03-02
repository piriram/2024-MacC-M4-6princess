# 카메라 3:4 유지 + 장기 유지보수형 옵션 설계 문서

_프로젝트: 6princess (Refactor/camera-uikit-snapkit 기준)_  
목표: 카메라 미리보기와 결과물의 3:4 비율을 **항상 보존**하고, 향후 비율/정책 변경을 **한 곳에서 쉽게** 변경 가능하게 하는 설계

---

## 1) 문제 정의

현재/향후에서 가장 자주 생기는 실수:
- 뷰 레이아웃은 3:4으로 맞췄는데 캡처 결과는 원본 비율 유지 실패
- `snapkit` 제약은 바꿨는데 `videoGravity`는 그대로라 왜곡 또는 여백 발생
- 옵션 A/B/C를 하드코딩/브랜치로 분기해 추적이 어려움

해결 방향: **비율 정책을 코드 한 곳에서 소유**하고, 미리보기와 결과물을 같은 정책으로 처리한다.

---

## 2) 권장 아키텍처 (장기 유지보수 우선)

### 2.1 핵심 개념

- **AspectSpec**: 비율 자체(예: 3:4, 9:16, 1:1)
- **CameraDisplayPolicy**: 미리보기/출력 처리 룰(여백/잘림)
- **Pipeline에서 단일 진실 값(SSOT) 참조**: 레이아웃·미리보기·이미지 처리·영상 처리 모두 동일 정책 사용

### 2.2 디렉터리 예시

```
Source/
  Config/
    CameraLayoutConfig.swift
    CameraPolicy.swift
  Service/
    CameraLayoutEngine.swift
    CameraOutputPipeline.swift
  View/
    Camera/
      CameraLayoutView.swift
      CameraPreview.swift
```

---

## 3) 구체 옵션 제안 (운영성 기준별)

## Option A) **최소 변경형 (Short Term)**

**특징:** 빠르게 적용

- `AspectSpec` enum + `multiplier` 계산
- `VideoGravity: .resizeAspect`로 비율 유지(레터박스 허용)
- 결과는 `cropToAspect`로 중앙 크롭 처리

**장단점**
- 장점: 구현 난이도 낮고 즉시 효과
- 단점: 정책 확장(예: 기기별 예외, 배포 중 비율 변경) 관리가 약함

---

## Option B) **권장형 (Long Term Core)**

**특징:** 실제 운영용 기준

- `CameraAspect` + `CameraDisplayPolicy` 2개 분리
  - `CameraAspect`: 3:4, 9:16 등 비율 자체
  - `CameraDisplayPolicy`: 미리보기/출력 동작 전략
- Policy 변경은 `CameraPolicyProvider.current` 한 곳만 수정

**비추기 장점**
- 기능 추가/변경이 쉬움
- 테스트 작성 쉬움
- 브랜치 분기 없이 하나의 코드베이스에서 모드 전환 가능

**정책 예시**
- `PreviewMode.fit` → `videoGravity = .resizeAspect`
- `PreviewMode.fill` → `videoGravity = .resizeAspectFill`
- `ResultMode.cropCenter`
- `ResultMode.padToFit`
- `ResultMode.passThrough`

---

## Option C) **구성 파일/원격 설정형 (최대 확장성)**

**특징:** 운영 중에도 비율 정책을 바꿔야 하는 팀에 유리

- 앱 설정 JSON 또는 Remote Config 기반
- 앱 실행 시 정책 파싱 + 검증 + fallback
- 예: 실험군 A: 3:4, 실군 B: 4:3

**주의점**
- 설정 값 검증 실패 시 기본 정책으로 fallback
- 정책 스키마 버전 관리 필요
- 잘못된 설정 배포 방지용 안전장치 필요

---

## 4) 권장 구현안 (Option B + C 하이브리드)

### 4.1 AspectSpec

```swift
enum CameraAspect: String, CaseIterable {
    case ratio3x4 = "3:4"
    case ratio9x16 = "9:16"
    case ratio1x1 = "1:1"

    var width: CGFloat {
        switch self {
        case .ratio3x4: return 3
        case .ratio9x16: return 9
        case .ratio1x1: return 1
        }
    }

    var height: CGFloat {
        switch self {
        case .ratio3x4: return 4
        case .ratio9x16: return 16
        case .ratio1x1: return 1
        }
    }

    var multiplier: CGFloat { height / width }
}

enum CameraPreviewMode: String {
    case fit      // .resizeAspect (비율 보존, 여백 허용)
    case fill     // .resizeAspectFill (비율 보존, 잘림 허용)
}

enum CameraOutputMode: String {
    case cropCenter   // 중앙 크롭 (권장)
    case padToFit     // 여백 추가
    case passThrough  // 원본 유지
}

struct CameraDisplayPolicy {
    let aspect: CameraAspect
    let previewMode: CameraPreviewMode
    let outputMode: CameraOutputMode
    let strictNoDistortion: Bool
}
```

### 4.2 전역 정책 제공자 (SSOT)

```swift
final class CameraPolicyProvider {
    static let shared = CameraPolicyProvider()
    var current: CameraDisplayPolicy = .init(
        aspect: .ratio3x4,
        previewMode: .fit,
        outputMode: .cropCenter,
        strictNoDistortion: true
    )
}
```

### 4.3 레이아웃 적용 지점

```swift
func applyCameraLayout(in container: UIView) {
    let policy = CameraPolicyProvider.shared.current
    container.snp.remakeConstraints { make in
        make.width.equalToSuperview().inset(20)
        make.height.equalTo(container.snp.width).multipliedBy(policy.aspect.multiplier)
    }
}

func applyPreviewGravity(_ layer: AVCaptureVideoPreviewLayer) {
    layer.videoGravity = {
        switch CameraPolicyProvider.shared.current.previewMode {
        case .fit: return .resizeAspect
        case .fill: return .resizeAspectFill
        }
    }()
}
```

### 4.4 결과물 처리

```swift
func applyOutputPolicy(to image: UIImage) -> UIImage {
    let policy = CameraPolicyProvider.shared.current
    switch policy.outputMode {
    case .cropCenter:
        return image.croppedToAspect(ratio: policy.aspect)
    case .padToFit:
        return image.paddedToAspect(ratio: policy.aspect)
    case .passThrough:
        return image
    }
}
```

---

## 5) 마이그레이션 계획

1. `CameraPolicy` 타입 추가
2. `CameraView` 제약 계산 지점 하나에 `aspect.multiplier` 적용
3. preview layer 생성/업데이트 지점에 `previewMode` 연결
4. 결과 캡처 파이프라인에 `outputMode` 적용
5. 기존 하드코딩 값 제거 (숫자/문자열 직접 사용 금지)
6. 단위 테스트 추가
   - aspect 변환 테스트
   - crop/pad 결과 비율 검증
   - 정책별 스냅샷/레이아웃 테스트

---

## 6) 안전 장치 (실무에서 꼭 넣을 것)

- `strictNoDistortion == true`면 scaleTransform 기반 강제 왜곡 리턴 금지
- `Policy decode 실패` 시 기본값(`3:4 + fit + cropCenter`) fallback
- 비율 변경 후 자동 검증 로그: 미리보기 높이/결과 비율

---

## 7) 운영 규칙

- **비율 변경은 `CameraPolicyProvider.current.aspect`에서만**
- 코드에서 `3:4`, `9:16` literal(직접 수치) 추가 금지
- PR에는 다음 항목을 반드시 기록:
  - 정책 변경 이유
  - 미리보기 영향(여백/잘림)
  - 결과물 영향(크롭/패딩)

---

## 8) 추천 결과

- 단기: Option A로 시작 후
- 중기: Option B 정식 도입
- 장기: 운영 요구가 생기면 Option C 확장

"비율 자체(what) + 렌더링 방식(how) + 결과물 처리(then)"를 분리하면,
**3:4은 깨지지 않고, 나중에 ratio 교체/전략 변경이 극도로 쉬워진다.**