# 🎀 Frameet 🎀 언제 어디서나 최애와 함께 사진 찍기

## 💡 Solution Concept

> 팬이 아이돌 사진을 불러오고,
> 자신이 원하는 사진을 넣어 **자동 배경 제거 + 프레임 조합**으로
> **마치 아이돌과 함께 찍은 듯한 결과물**을 만들 수 있는 앱!

---

## ⚙️ 기술 아키텍처 개요

| 영역     | 주요 기술                             | 설명                            |
| ------ | --------------------------------- | ----------------------------- |
| 이미지 처리 | **Vision, Core Image, VisionKit** | 자동 배경 제거 / 피사체 추출 / 마스크 기반 합성 |
| UI 계층  | **SwiftUI + UIKit 혼합**            | 편집 캔버스 및 프레임 뷰 구현             |
| 데이터 저장 | **Core Data (1:N 관계)**            | 프레임별 편집 요소 관리 및 재편집 지원        |
| 성능 최적화 | **CIContext 재사용, 다운샘플링, 비동기 처리**  | GPU 캐시 효율화, UI 프리즈 방지         |
| 분석/로그  | **Firebase Analytics**            | 사용 패턴 분석, 이벤트 기반 사용자 행동 추적    |

---

## 🧠 핵심 기술 구현

### 1️⃣ 자동 배경 제거 (Vision + Core Image)

* `VNGenerateForegroundInstanceMaskRequest`로 전경 마스크 추출
* `CIFilter.blendWithMask`를 통해 투명 배경으로 자연스럽게 합성

```swift
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])
let mask = try request.results?.first?.generateScaledMaskForImage(forInstances: ...)
let output = CIFilter.blendWithMask(inputImage, maskImage: CIImage(cvPixelBuffer: mask))
```

> ✅ 사용자 1-클릭으로 배경 제거
> ✅ Vision 기반 마스크로 픽셀 경계 자연스럽게 유지

---

### 2️⃣ 다중 피사체 선택 (VisionKit Subject Lift)

* `ImageAnalyzer`로 피사체 감지
* `ImageAnalysisInteraction`에서 유저가 선택한 피사체만 추출

```swift
let config = ImageAnalyzer.Configuration([.visualLookUp])
let analysis = try await analyzer.analyze(image, configuration: config)
interaction.analysis = analysis
let result = try await interaction.image(for: highlightedSubjects)
```

> ✅ 여러 피사체 중 원하는 대상만 선택
> ✅ Vision 파이프라인과 병행 가능 — 자연스러운 통합 편집

---

### 3️⃣ 고해상도 렌더링 (SwiftUI ImageRenderer)

* 모든 기기에서 **4:3 비율** 유지
* `ImageRenderer` + `UIScreen.scale` 기반 해상도 정규화

```swift
let renderer = ImageRenderer(content: view)
renderer.scale = UIScreen.main.scale + 1
let result = renderer.uiImage
```

> ✅ 썸네일/저장/공유 간 품질 불일치 제거
> ✅ SNS 업로드 시 원본 손실 최소화

---

### 4️⃣ Core Data 1:N 관계 모델링

* `StoreImages` (프레임) ↔ `Subject` (요소) 구조
* 각 Subject에 회전·위치·스케일 정보 저장 → 재편집 가능

```swift
newSubject.angle = subject.angle.degrees
newSubject.scale = subject.scale
newImage.addToSubjects(newSubject)
```

> ✅ 데이터 구조화로 편집 이력 관리
> ✅ 스키마 변경 시 마이그레이션 매핑으로 무손실 이전

---

### 5️⃣ 메모리 & 성능 최적화

* `CGImageSourceCreateThumbnailAtIndex`로 썸네일 다운샘플링
* `CIContext` 인스턴스 재사용으로 GPU 캐시 효율 증가
* Vision/CI 연산을 Task 분리로 비동기 처리

```swift
let downsampled = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
let blended = try await Task.detached { vision.blendWithMask(...) }.value
```

> ✅ 메모리 사용량 40% 감소
> ✅ UI 스레드 프리즈 없이 실시간 편집

---

## 📊 기술적 성과

| 항목           | 성과                    |
| ------------ | --------------------- |
| 자동 배경 제거     | 원터치 처리로 사용자 접근성 ↑     |
| VisionKit 통합 | 다중 피사체 선택 기능 구현       |
| 렌더링 품질       | 기기별 일관된 4:3 결과 보장     |
| 데이터 모델링      | 재편집 가능한 Core Data 구조  |
| 성능 최적화       | 다운샘플링·비동기화로 안정적 UX 확보 |

---

## 📲 실행 환경

| 항목                    | 버전                                                                 |
| --------------------- | ------------------------------------------------------------------ |
| iOS Deployment Target | **iOS 18.0 이상**                                                    |
| IDE                   | **Xcode 16+**                                                      |
| 언어                    | **Swift 5.10**                                                     |
| 프레임워크                 | Vision, CoreImage, VisionKit, SwiftUI, CoreData, FirebaseAnalytics |

---

## 🧩 구조 설계

```text
Frameet
 ├── View
 │   ├── PhotosPickerView
 │   ├── CanvasEditView
 │   └── FramePreviewView
 ├── ViewModel
 │   ├── PhotosPickerViewModel
 │   ├── DFEditViewModel
 │   ├── SubjectLiftViewModel
 │   └── RenderManager
 ├── Service
 │   ├── VisionService
 │   ├── DownsampleService
 │   └── CoreDataManager
 └── Model
     ├── StoreImages (Entity)
     └── Subject (Entity)
```

> MVVM 구조 기반으로 View-Logic 분리
> CoreData, Vision, SwiftUI Renderer 등을 **Service 단일 책임 구조**로 구성
