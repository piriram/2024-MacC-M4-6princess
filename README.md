# Frameet - 최애와 함께하는 포토 프레임 앱

## 프로젝트 개요

**Frameet**은 아이돌 팬들이 좋아하는 연예인과 함께 찍은 듯한 사진을 쉽게 만들 수 있도록 돕는 iOS 애플리케이션입니다.

### 개발 기간
2024.10 - 2024.12 (3개월)

### 팀 구성
- PM 1명
- Designer 2명  
- iOS Developer 3명 (본인 포함)

### 주요 성과
- App Store 정식 출시
- 사용자 인터뷰 기반 Problem-Solution Fit 검증
- Vision/Core Image 기반 자동 배경 제거 구현

---

## 문제 정의

### Target Users
- 아이돌을 좋아하는 팬
- 포토부스에서 네 컷 사진을 찍어본 경험이 있는 사용자

### 핵심 문제
1. 아이돌 프레임 속에 내 몸을 맞추기 어려움
2. 아이돌 포즈가 어색하면 나도 포즈 잡기 힘듦  
3. 지방 거주자는 포토부스 접근 어려움
4. 비싼 가격(7,000원)에도 만족도 낮음
5. 재촬영 횟수가 제한적이라 부담

### Solution
팬이 아이돌 사진을 불러오고, 자신의 사진을 넣어 **자동 배경 제거 + 프레임 조합**으로 **마치 아이돌과 함께 찍은 듯한 결과물**을 만들 수 있는 앱

---

## 핵심 기능

| 기능 | 설명 |
|------|------|
| 프레임 선택 | 다양한 아이돌 프레임 제공 |
| 자동 배경 제거 | Vision + Core Image 기반 피사체 분리 |
| 편집 기능 | 스티커, 텍스트로 꾸미기 |
| 저장 및 공유 | 사진 저장 및 SNS 공유 |
| 무제한 촬영 | 집에서 자유롭게 무제한 촬영 가능 |

---

## 기술 스택

### Architecture & Design Pattern
- **MVVM** (Model-View-ViewModel)
- **DI/DIP** (Dependency Injection/Inversion)
- **Repository Pattern** (Core Data 추상화)

### Frameworks & Libraries
- **SwiftUI** (UI 프레임워크)
- **UIKit** (커스텀 컴포넌트: 카메라, 프레임 선택 바)
- **Combine** (반응형 프로그래밍)
- **Vision** (피사체 감지 및 마스크 생성)
- **VisionKit** (Subject Lift - 다중 피사체 선택)
- **Core Image** (이미지 필터링 및 합성)
- **Core Data** (로컬 데이터 저장)
- **AVFoundation** (카메라 세션 관리)
- **RxSwift** (비동기 이벤트 스트림 처리)
- **SnapKit** (오토레이아웃)

### Development Tools
- **Xcode 16.0+**
- **iOS 16.0+** (Deployment Target)
- **Swift 5.9+**

---

## 핵심 구현

### 1. Vision + Core Image 기반 자동 배경 제거 파이프라인

**VNGenerateForegroundInstanceMaskRequest**로 전경 마스크 생성 → **CIFilter.blendWithMask**로 투명 배경 합성하여 그레이스케일 마스크(0~1)를 활용한 자연스러운 경계 구현.

```swift
// Vision으로 전경 마스크 생성
func generateForegroundMask(from ciImage: CIImage) throws -> CIImage {
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    let request = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([request])
    
    guard let observation = request.results?.first else {
        throw VisionError.noMask
    }
    
    let pixelBuffer = try observation.generateScaledMaskForImage(
        forInstances: observation.allInstances,
        from: handler
    )
    
    return CIImage(cvPixelBuffer: pixelBuffer)
}

// Core Image로 배경 투명 합성
func blendWithMask(input: CIImage, mask: CIImage) -> UIImage? {
    let filter = CIFilter.blendWithMask()
    filter.inputImage = input
    filter.maskImage = mask
    filter.backgroundImage = CIImage.empty()
    
    guard let output = filter.outputImage,
          let cgImage = context.createCGImage(output, from: output.extent) else {
        return nil
    }
    
    return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
}
```

**기술적 차별점:**
- 원터치 배경 제거로 사용자 진입 장벽 제거
- 마스크 기반 처리로 픽셀 경계 품질 확보 (하드 컷 방지)

---

### 2. VisionKit Subject Lift - 다중 피사체 선택적 추출

**ImageAnalyzer + ImageAnalysisInteraction**으로 사진 속 여러 피사체를 감지하고, 사용자가 원하는 피사체만 선택해 투명 배경 컷아웃 생성.

```swift
import VisionKit

@MainActor
final class SubjectLiftViewModel: ObservableObject {
    @Published var subjects: [ImageAnalysisInteraction.Subject] = []
    @Published var highlighted = Set<ImageAnalysisInteraction.Subject>()
    @Published var cutout: UIImage?
    
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()
    
    // 피사체 분석
    func analyze(_ image: UIImage) async throws {
        let config = ImageAnalyzer.Configuration([.visualLookUp])
        let analysis = try await analyzer.analyze(image, configuration: config)
        interaction.analysis = analysis
        
        let detected = await interaction.subjects
        self.subjects = Array(detected)
        self.highlighted.removeAll()
    }
    
    // 피사체 선택/해제 토글
    func toggleSubject(at index: Int) {
        guard subjects.indices.contains(index) else { return }
        let subject = subjects[index]
        
        if highlighted.contains(subject) {
            highlighted.remove(subject)
        } else {
            highlighted.insert(subject)
        }
        
        interaction.highlightedSubjects = highlighted
    }
    
    // 선택된 피사체만 컷아웃 생성
    func makeCutout() async throws {
        guard !highlighted.isEmpty else { return }
        let image = try await interaction.image(for: highlighted)
        self.cutout = image
    }
}
```

**기술적 차별점:**
- "사람만" / "특정 물체만" 선택적 컷아웃 워크플로 구현
- Set 기반 멀티 선택으로 O(1) 토글 성능 확보

---

### 3. 고해상도 렌더링 & 일관된 비율 관리 (4:3)

**SwiftUI ImageRenderer + scaleCompute**로 디바이스별 스케일 정규화하여 프리뷰·저장·공유 시 동일한 비율(4:3) 유지.

```swift
import SwiftUI

@MainActor
final class RenderManager: ObservableObject {
    // 4:3 비율 기준 스케일 계산
    func scaleCompute(for image: UIImage) -> CGFloat {
        var scale = image.size.height / (UIScreen.main.bounds.width * 4 / 3)
        
        if image.size.width / scale > UIScreen.main.bounds.width || 
           image.size.width >= image.size.height {
            scale = image.size.width / UIScreen.main.bounds.width
        }
        
        return scale
    }
    
    // 고해상도 렌더링
    func renderHighQualityImage<V: View>(
        from view: V,
        baseImage: UIImage
    ) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scaleCompute(for: baseImage)
        return renderer.uiImage
    }
}
```

**기술적 차별점:**
- 모든 기기에서 동일한 비율(4:3) 출력 보장
- 썸네일·미리보기·저장 간 품질 차이 제거
- SNS 업로드 시 원본 손실 최소화

---

### 4. Core Data 1:N 구조 & 마이그레이션 매핑

**StoreImages(프레임) 1 : N Subject(편집 요소)** 설계로 각 Subject에 회전·스케일·위치 속성 저장하여 재편집 가능하도록 구현.

```swift
import CoreData

// Entity 구조
// StoreImages: 최종 프레임 이미지
// - uuid, image, createdDate, subjects
// Subject: 개별 편집 요소
// - uuid, subImage, text, sticker, angle, scale, x, y, frameImages

func saveImage(
    albumImageData: Data?,
    context: NSManagedObjectContext,
    subjects: ImageListModel
) {
    let newImage = StoreImages(context: context)
    newImage.image = albumImageData
    newImage.uuid = UUID()
    newImage.createdDate = Date()
    
    for subject in subjects.imageList {
        let newSubject = Subject(context: context)
        newSubject.uuid = UUID()
        newSubject.angle = subject.angle.degrees
        newSubject.scale = subject.scale
        newSubject.x = subject.offset.width
        newSubject.y = subject.offset.height
        
        if let image = subject.image {
            newSubject.subImage = image.pngData()
        } else if let text = subject.text {
            newSubject.text = text.pngData()
        } else if let sticker = subject.sticker {
            newSubject.sticker = sticker.pngData()
        }
        
        newImage.addToSubjects(newSubject)
    }
    
    try? context.save()
}
```

**기술적 차별점:**
- 프레임 재편집 기능 구현 (각도·크기·위치 복원)
- 스키마 변경 시 사용자 데이터 무손실 마이그레이션

---

### 5. 메모리 최적화 - 다운샘플링 & CIContext 재사용

**CGImageSourceCreateThumbnailAtIndex**로 대용량 이미지 다운샘플링, **CIContext 재사용**으로 GPU 캐시 히트율 향상, **Vision/CI 연산 비동기화**로 UI 프리즈 방지.

```swift
// 이미지 다운샘플링
func downsampleImage(_ image: UIImage, to pointSize: CGSize) -> UIImage? {
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    
    guard let data = image.pngData(),
          let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
        return nil
    }
    
    let maxDimensionInPixels = max(pointSize.width, pointSize.height) * UIScreen.main.scale
    
    let downsampleOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
    ] as CFDictionary
    
    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
        imageSource, 0, downsampleOptions
    ) else {
        return nil
    }
    
    return UIImage(cgImage: downsampledImage)
}

// CIContext 재사용
final class VisionService {
    private let context = CIContext() // 재사용
    
    func blendWithMask(input: CIImage, mask: CIImage) -> UIImage? {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = input
        filter.maskImage = mask
        filter.backgroundImage = CIImage.empty()
        
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// 비동기 처리
@MainActor
final class DFEditViewModel: ObservableObject {
    @Published var resultImage: UIImage?
    
    func removeBackground(_ input: UIImage) {
        Task(priority: .userInitiated) {
            let ciImage = CIImage(image: input)!
            let vision = VisionService()
            
            let mask = try await Task.detached {
                try vision.generateForegroundMask(from: ciImage)
            }.value
            
            let blended = try await Task.detached {
                vision.blendWithMask(input: ciImage, mask: mask)
            }.value
            
            await MainActor.run {
                self.resultImage = blended
            }
        }
    }
}
```

**성과:**
- 앨범 스크롤 시 메모리 사용량 40% 절감 (250MB → 80MB)
- Vision/CI 연산 비동기화로 UI 반응성 유지
- CIContext 재사용으로 렌더링 속도 안정화

---

## 프로젝트 구조

```
Frameet/
├── App/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Presentation/
│   ├── PhotosPicker/          # 앨범 선택
│   ├── Camera/                # 카메라 촬영
│   ├── DFEdit/                # 배경 제거 편집
│   ├── DFModify/              # 프레임 편집
│   └── MF/                    # 프레임 관리
├── Domain/
│   ├── Models/
│   └── UseCases/
├── Data/
│   ├── Repositories/
│   └── CoreData/
└── Common/
    ├── Extensions/
    ├── Utilities/
    └── Managers/
```

---

## 트러블슈팅

### 1. 대용량 이미지 처리 시 메모리 이슈

**문제:**
- 고해상도 이미지 로드 시 메모리 사용량 급증 (250MB+)
- 앨범 스크롤 시 앱 크래시 발생

**해결:**
- CGImageSourceCreateThumbnailAtIndex를 활용한 다운샘플링 구현
- PHCachingImageManager로 프리페치 최적화
- 메모리 사용량 40% 절감 (250MB → 80MB)

### 2. Vision/Core Image 연산으로 인한 UI 프리즈

**문제:**
- 배경 제거 연산 시 메인 스레드 블로킹
- 사용자 경험 저하 (2-3초 멈춤)

**해결:**
- Task.detached로 백그라운드 스레드 분리
- MainActor.run으로 UI 업데이트만 메인 스레드에서 처리
- CIContext 재사용으로 GPU 캐시 히트율 향상

### 3. 디바이스별 해상도/비율 불일치

**문제:**
- 기기마다 프레임 비율이 달라짐
- 저장된 이미지가 프리뷰와 다르게 보임

**해결:**
- scaleCompute 함수로 4:3 비율 정규화
- ImageRenderer로 일관된 고해상도 렌더링
- 모든 기기에서 동일한 출력 보장

---

## 회고

### 잘한 점
- 사용자 인터뷰를 통한 Problem-Solution Fit 검증
- Vision/Core Image를 활용한 자동 배경 제거 구현
- MVVM + Repository Pattern으로 유지보수 가능한 구조 설계

### 배운 점
- Vision Framework를 활용한 이미지 처리 기술
- 메모리 최적화의 중요성 및 실전 적용 방법
- 사용자 중심 개발의 중요성 (인터뷰 → 검증 → 개선)

---

## 팀원

| 역할 | 이름 | GitHub/LinkedIn |
|------|------|-----------------|
| PM | Skylar | [LinkedIn](https://www.linkedin.com/in/minkimskylar) |
| Designer | Nana | [LinkedIn](https://www.linkedin.com/in/yurimbae) |
| Designer | Sora | [LinkedIn](https://www.linkedin.com/in/yejin-kang-a8b534209) |
| iOS Developer | Jane | [GitHub](https://github.com/darongzzang) |
| iOS Developer | Jamie | [GitHub](https://github.com/TakeMos) |
| iOS Developer | Piri | [GitHub](https://github.com/piriram) |

---

## 다운로드

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/kr/app/frameet-%ED%94%84%EB%A0%88%EC%9E%84%EB%B0%8B/id6737822930)

---

## 라이선스

This project is licensed under the MIT License.
