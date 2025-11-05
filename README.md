# 🎀 Frameet (프레임밋)

**"언제 어디서나 최애와 함께 사진 찍기"**

아이돌 팬들이 좋아하는 연예인과 함께 찍은 것 같은 사진을 쉽게 만들 수 있는 iOS 앱

---
## 프로젝트 소개

### Challenge Statement
아이돌을 좋아하는 팬들이 **좋아하는 연예인과 함께 찍은 것 같은 사진을 쉽게 만들 수 있도록 돕자.**

### Target Users
- 아이돌을 좋아하는 모든 팬
- 특히 **포토부스에서 네 컷 사진을 찍어본 경험이 있는 팬**

### 문제 정의 및 해결 방안
|  구분 | 문제점 (기존 오프라인 포토부스의 한계) | 해결방안 (Frameet 솔루션)      |
| :-: | :--------------------- | :---------------------- |
|  1  | 원하는 아이돌 프레임이 없음        | 사용자가 직접 최애 사진으로 프레임 제작  |
|  2  | 프레임 속 포즈와 크기가 맞지 않음    | 자동 배경 제거로 자연스러운 합성      |
|  3  | 지방 거주자는 접근이 어려움        | 집에서 무제한 촬영 가능           |
|  4  | 비싼 가격 (약 7,000원)       | 무료 혹은 저렴한 디지털 촬영 제공     |
|  5  | 재촬영 기회 제한              | 원하는 만큼 촬영 및 편집 가능       |
|  6  | 꾸미기 기능 제한              | 스티커와 텍스트로 자유롭게 꾸미기      |
|  7  | 결과물 활용 제한              | 저장 및 SNS 공유로 확장된 팬활동 가능 |


---

## 주요 기능
|   구분  | 기능명         | 주요 내용                                                                                                     |
| :---: | :---------- | :-------------------------------------------------------------------------------------------------------- |
| **1** | **프레임 제작**  | - Vision Framework 기반 **자동 배경 제거**<br>- 사용자가 선택한 최애 사진의 **피사체만 분리**<br>- **Canvas 기반 수동 보정 기능** (붓 / 지우개) |
| **2** | **사진 촬영**   | - **AVFoundation 커스텀 카메라 구현**<br>- 타이머 (3 / 5 / 7초)<br>- 전·후면 카메라 전환<br>- **핀치 제스처 줌 기능**                 |
| **3** | **편집 기능**   | - **밝기 / 채도 / 대비 조정**<br>- 스티커 및 텍스트 추가<br>- **드래그, 회전, 크기 조절 제스처 지원**<br>- 원본 / 수정본 비교 기능                |
| **4** | **저장 및 관리** | - **Core Data 기반 로컬 저장소 관리**<br>- 프레임 목록 관리 (삭제 / 재편집)<br>- **고해상도 이미지 저장 및 공유**                          |


---

## 💻 기술 스택

### Development
- **Language**: Swift 5.9
- **Minimum iOS**: 17.0
- **Architecture**: MVVM + Coordinator Pattern
- **UI Framework**: SwiftUI + UIKit 

### Core Frameworks
```swift
- Vision Framework          // 피사체 분리
- Core Image               // 이미지 합성 및 필터링
- AVFoundation            // 카메라 제어
- Core Data               // 로컬 데이터 관리
- VisionKit               // Subject Lift (고급 피사체 추출)
```
---
## 🖥️ Main Flow


![6@3x](images/screenshot1.png)
![7@3x](./images/screenshot2.png)


---

## 아키텍처

### MVVM + Coordinator Pattern

```
 Frameet
├── 📁 Views (SwiftUI + UIKit)
│   ├── PhotosPickerView
│   ├── DFEditView (배경 제거)
│   ├── DFModifyView (프레임 편집)
│   ├── CameraBottomView
│   └── MFView (프레임 관리)
│
├── 📁 ViewModels
│   ├── PhotosPickerViewModel
│   ├── DFEditViewModel
│   ├── DFModifyViewModel
│   └── CameraViewModel
│
├── 📁 Models
│   ├── SubjectImage
│   ├── PickedImageModel
│   └── CoreData Models
│
├── 📁 Managers
│   ├── FrameManager
│   ├── NavigationManager
│   ├── CameraManager
│   └── PersistenceController
│
└── 📁 Services
    └── VisionService
```

### 데이터 흐름

```
사진 선택 → 배경 제거 → 프레임 편집 → Core Data 저장
    ↓           ↓            ↓              ↓
Photos    Vision        Gesture        Storage
Picker    + CI         Handling        Manager
```

---

## 핵심 구현 사항

### 1. Vision Framework 기반 피사체 분리

**자동 배경 제거**
```swift
// Vision으로 전경 마스크 생성
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])

// Core Image로 투명 배경 합성
let filter = CIFilter.blendWithMask()
filter.inputImage = originalImage
filter.maskImage = maskFromVision
filter.backgroundImage = CIImage.empty()
```

**핵심 포인트**:
- Instance Segmentation으로 그레이스케일 마스크 생성
- `blendWithMask`로 경계가 자연스러운 합성
- Canvas 기반 수동 보정으로 정밀도 향상

### 2. VisionKit Subject Lift (iOS 17+)

**다중 피사체 선택적 추출**
```swift
let analyzer = ImageAnalyzer()
let analysis = try await analyzer.analyze(image, 
    configuration: .init([.visualLookUp]))

// 원하는 피사체만 선택
interaction.highlightedSubjects = selectedSubjects
let cutout = try await interaction.image(for: highlightedSubjects)
```

**핵심 포인트**:
- 사람/동물/객체 등 의미 단위 피사체 인식
- 알파 포함 고품질 컷아웃 생성
- 특정 대상만 교체/수정 가능

### 3. 커스텀 카메라 구현

**AVFoundation 기반 카메라 제어**
```swift
class CameraManager {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    
    func setupCamera() {
        session.sessionPreset = .photo
        // device input 및 output 설정
    }
    
    func zoom(_ factor: CGFloat) {
        device.ramp(toVideoZoomFactor: factor, withRate: 2.0)
    }
}
```

**핵심 포인트**:
- 전/후면 카메라 전환
- 제스처 기반 부드러운 줌 (1.0x ~ 4.0x)
- 타이머 촬영 및 무음 셔터
- 4:3 비율 자동 크롭

### 4. Core Data 마이그레이션

**1:N 관계 설계**
```
StoreImages (프레임)
    ├── uuid: UUID
    ├── image: Data
    ├── createdDate: Date
    └── subjects [Subject]

Subject (편집 요소)
    ├── subImage: Data
    ├── angle, scale, x, y: Double
    └── frameImages → StoreImages
```

**마이그레이션 매핑**
- 수동 Mapping Model로 데이터 보존
- 관계(Relationship) 양방향 매핑
- 버전 업데이트 시 사용자 데이터 유지

### 5. 고해상도 렌더링

**디바이스별 스케일 관리**
```swift
func scaleCompute(_ image: UIImage) -> CGFloat {
    var scale = image.size.height / (UIScreen.main.bounds.width * 4/3)
    if image.size.width / scale > UIScreen.main.bounds.width {
        scale = image.size.width / UIScreen.main.bounds.width
    }
    return scale
}

let renderer = ImageRenderer(content: view)
renderer.scale = scaleCompute(baseImage)
```

**핵심 포인트**:
- 4:3 비율 통일로 디바이스 간 일관성 보장
- ImageRenderer로 SwiftUI 뷰 → UIImage 변환
- 프리뷰-저장-공유 품질 동일

### 6. 대용량 앨범 최적화

**다운샘플링 & 지연 로딩**
```swift
// CGImageSource 다운샘플링
let options = [
    kCGImageSourceThumbnailMaxPixelSize: targetSize,
    kCGImageSourceCreateThumbnailFromImageAlways: true
] as CFDictionary

let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
```

**핵심 포인트**:
- 60장 단위 페이징
- 스크롤 하단 감지 시 추가 로드
- PHCachingImageManager로 썸네일 캐싱
- 메모리 사용량 40% 절감

### 7. 메모리 최적화

**CIContext 재사용**
```swift
private let ciContext = CIContext() // 싱글톤 패턴

func applyFilter(_ image: CIImage) -> UIImage? {
    let filtered = image.applyingFilter("CIBlendWithMask", ...)
    guard let cg = ciContext.createCGImage(filtered, from: filtered.extent)
    return UIImage(cgImage: cg)
}
```

**비동기 처리**
```swift
Task(priority: .userInitiated) {
    let mask = try await Task.detached {
        try vision.generateForegroundMask(from: ciImage)
    }.value
    
    await MainActor.run {
        self.resultImage = blended
    }
}
```

## 성능 지표

| 항목 | 개선 전 | 개선 후 |
|------|---------|---------|
| 앨범 초기 로딩 | ~3초 | ~0.3초 |
| 메모리 사용량 | 250MB+ | 80MB 이하 |
| 배경 제거 속도 | 2-3초 | 1-1.5초 |
| 스크롤 FPS | 30-40 | 60  |


## 👩‍💻 Team 6공주 소개

<div align="left">

<table>
  <tr>
    <td align="center">
        <a href="https://www.linkedin.com/in/minkimskylar">
      <img src="/images/skyla.png" width="88" alt="Skylar"/>
        </a><br />
      <a href="https://www.linkedin.com/in/minkimskylar"><b>Skylar</b></a><br />PM
    </td>
    <td align="center">
        <a href="https://www.linkedin.com/in/yurimbae">
      <img src="/images/nana.png" width="88" alt="Nana"/>
        </a><br />
     <a href="https://www.linkedin.com/in/yurimbae"> <b>Nana</b></a><br />디자이너
    </td>
    <td align="center">
        <a href="https://www.linkedin.com/in/yejin-kang-a8b534209/">
      <img src="/images/sora.png" width="88" alt="Sora"/>
        </a><br />
      <a href="https://www.linkedin.com/in/yejin-kang-a8b534209"><b>Sora</b></a><br />디자이너
    </td>
    <td align="center">
        <a href="https://github.com/darongzzang">
      <img src="/images/jane.png" width="88" alt="Jane"/>
        </a><br />
     <a href="https://github.com/darongzzang"> <b>Jane</b></a><br />iOS 개발
    </td>
    <td align="center">
        <a href="https://github.com/TakeMos">
      <img src="/images/jamie.png" width="88" alt="Jamie"/>
        </a><br />
      <a href="https://github.com/TakeMos"><b>Jamie</b></a><br />iOS 개발
    </td>
    <td align="center">
  <a href="https://github.com/piriram">
    <img src="/images/piri.png" width="88" alt="Piri"/>
  </a><br />
 <a href="https://github.com/piriram"> <b>Piri</b></a><br />iOS 개발
</td>

  </tr>
</table>

</div>

## 🎯 프로젝트 목표

1. **앱으로 수익화 달성**
2. **사용자 인터뷰와 테스트를 자주, 깊이있게 진행**
3. **아카데미 이후에도 지속적으로 유지·관리**


## ⬇ 프레임밋 실행
[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/kr/app/frameet-%ED%94%84%EB%A0%88%EC%9E%84%EB%B0%8B/id6737822930)

