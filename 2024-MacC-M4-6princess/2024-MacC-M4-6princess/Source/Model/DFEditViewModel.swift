import SwiftUI
import Vision
import CoreImage.CIFilterBuiltins
import VisionKit

@MainActor
class DFEditViewModel: ObservableObject {
    
    @Published var maskImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var inputImage: UIImage?
    @Published var maskImageList: [UIImage?] = []
    @Published var indexOfMask: Int = 0
    @Published var maskColor: Color = .pink
    @Published var opacity: CGFloat = 0.4
    
    @Published var deleteLines: Bool = false
    @Published var isShowThick: Bool = false
    @Published var showPreview: Bool = false
    
    @Published var isShowModifyFrame: Bool = false
    
    @Published var magnifyScale = 1.0
    @Published var lastScale = 1.0
    @Published var draggedOffSet: CGSize = .zero
    @Published var accumulatedOffSet: CGSize = .zero
    
    @Published var outputImage: UIImage?
    
    @Published var selectionModeIndex: Int = 3
    @Published var lines: [Line] = []
    @Published var thickness: Double = 10.0
    
    @Published var detectedObjects: Set<ImageAnalysisInteraction.Subject> = []
    @Published var clickedButton = false
    @Published var isRenderFailed = false
    @Published var appError: AppError?
    
    @Published var toastMessageOpacity: CGFloat = 1
    @Published var removingLoadingOpacity: CGFloat = 0
    
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    private let imagePipeline: ImagePipelining = ImagePipelineService()
    private let maskingService: SubjectMaskingServicing

    init(maskingService: SubjectMaskingServicing = SubjectMaskingServiceFactory.makeDefault()) {
        self.maskingService = maskingService
    }

    private func reportError(_ error: AppError, debug: String? = nil) {
        appError = error
        if let debug {
            print(debug)
        }
    }

    func changeMessageOpacity() {
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.toastMessageOpacity -= 0.1
            }
        }
    }
    private func generateImageForAllSelectedObjects() async throws {
        let allSubjectsImage = try await interaction.image(for: interaction.highlightedSubjects)
        outputImage = allSubjectsImage
    }
    
    private func analyzeImage(_ image: UIImage) async throws -> Set<ImageAnalysisInteraction.Subject> {
        
        let configuration = ImageAnalyzer.Configuration([.visualLookUp])
        let analysis = try await analyzer.analyze(image, configuration: configuration)
        interaction.analysis = analysis
        let detectedSubjects = await interaction.subjects
        return detectedSubjects
    }
    
    func detectSubject(inputImage: UIImage?, completionHandler: @escaping (Bool) -> Void) {
          Task { @MainActor in
              do {
                  guard let inputImage = inputImage else {
                      print("Input image is nil")
                      completionHandler(false) // 실패
                      return
                  }
                  
                  detectedObjects = try await self.analyzeImage(inputImage)
                  print("탐지된 피사체: \(detectedObjects.count)")
                  
                  for i in detectedObjects {
                      interaction.highlightedSubjects.insert(i)
                      try await generateImageForAllSelectedObjects()
                  }
                  
                  completionHandler(true) // 성공
              } catch {
                  print("Failed to detect objects: \(error)")
                  completionHandler(false) // 실패
              }
          }
      }
    
    func setScaleValue(minimum: CGFloat, maximum: CGFloat) {
        
        if magnifyScale < minimum {
            
            magnifyScale = minimum
            draggedOffSet = .zero
            accumulatedOffSet = .zero
            
        } else if magnifyScale > maximum {
            magnifyScale = maximum
        }
        lastScale = 1.0
        
    }
    
    func setScaleVolume(_ magnify: CGFloat) {
        
        let scaleVolume = magnify / lastScale
        magnifyScale *= scaleVolume
        lastScale = magnify
    }
    
    func getWidth() -> CGFloat {
        return inputImage?.size.width ?? 0
    }
    
    func getHeight() -> CGFloat {
        return inputImage?.size.height ?? 0
    }
    
    func showMaskImage(content: some View) {
        
        let render = ImageRenderer(content: content)
        render.scale = 1
        self.inputImage = render.uiImage
        self.removeBackground()
        if self.maskImageList.count == 0 && self.maskImage != nil {
            self.maskImageList.append(self.maskImage)
        }
        
    }
    
    func drawLines(startLocation: CGPoint, location: CGPoint) {
        guard let mode = Mode(rawValue: selectionModeIndex) else { return }

        if lines.isEmpty  {
            lines = [Line(color: .white, points: [startLocation], mode: mode, lineWidth: thickness  / magnifyScale)]
        } else {
            var newLine = Line(color: .white, points: [], mode: mode, lineWidth: thickness  / magnifyScale)
            if startLocation != lines[lines.count - 1].points.first {
                newLine.points = [startLocation]
                lines.append(newLine)
                print("Start new point")
            } else {
                print("Change point event")
                let changedValue = location
                lines[lines.count - 1].points.append(changedValue)
            }
        }
    }
    
    func toolSelect(_ selected: String) {
        
        if selectionModeIndex != 3 {
            
            if (selected == "brush" && selectionModeIndex == 0) || (selected == "erase" && selectionModeIndex == 1) {
                selectionModeIndex = 3
            } else if selected == "brush" && selectionModeIndex == 1 {
                selectionModeIndex = 0
            } else if selected == "erase" && selectionModeIndex == 0 {
                selectionModeIndex = 1
            }
            
        } else {
            
            if selected == "brush" {
                selectionModeIndex = 0
                
            } else {
                selectionModeIndex = 1
            }
        }
    }
    
    func deleteAllLines() {
        if deleteLines {
            lines.removeAll()
            deleteLines = false
        }
    }
    
    func updateLine(context: inout GraphicsContext) {
        
        for line in lines {
            var path = Path()
            path.addLines(line.points)
            if line.mode == .draw {
                context.blendMode = .normal
                context.stroke(path, with: .color(line.color), style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
            } else {
                context.blendMode = .clear
                context.stroke(path, with: .color(line.color), style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
    
//    func scaleCompute(_ image: UIImage) -> CGFloat {
//        var scale: CGFloat = image.size.height / (UIScreen.main.bounds.height * 0.76)
//        
//        if image.size.width / scale > UIScreen.main.bounds.width || image.size.width >= image.size.height {
//            scale = image.size.width / UIScreen.main.bounds.width
//            print("\(scale)")
//        }
//        print("\(image.size.width)  \(image.size.height)")
//        print("\(UIScreen.main.bounds.width) \(UIScreen.main.bounds.height)")
//        return scale
//    }
    
    func scaleCompute(_ image: UIImage) -> CGFloat {
        imagePipeline.displayScale(for: image, screenWidth: UIScreen.main.bounds.width)
    }
    
    func reDo() {
        if indexOfMask > 0 {
            indexOfMask -= 1
            maskImage = maskImageList[indexOfMask]
            deleteLines = true
        }
    }
    
    func unDo() {
        if maskImageList.count - 1 > indexOfMask {
            indexOfMask += 1
            maskImage = maskImageList[indexOfMask]
            deleteLines = true
        }
    }
    func createResult(completionHandler: @escaping (Bool) -> Void) {
        var resultImage: UIImage?

        guard let inputImage = CIImage(image: inputImage ?? UIImage()) else {
            reportError(.inputImageMissing, debug: "Failed to create CIImage")
            completionHandler(false)
            return
        }

        Task { @MainActor in
            guard let maskSource = maskImage,
                  let maskCIImage = CIImage(image: maskSource),
                  let outputImage = apply(mask: maskCIImage, to: inputImage),
                  let renderedImage = convertToUIImage(ciImage: outputImage) else {
                reportError(.maskCreationFailed, debug: "Mask image is nil")
                completionHandler(false)
                return
            }

            resultImage = renderedImage
            self.resultImage = resultImage
            completionHandler(true)
        }
    }
    
    func removeBackground() {
        
        var mask: UIImage?
        var resultImage: UIImage?
        
        guard let inputImage = CIImage(image: inputImage ?? UIImage()) else {
            reportError(.inputImageMissing, debug: "Failed to create CIImage")
            return
        }
        
        Task { @MainActor in
            guard let fakeMask = createMask(from: inputImage) else {
                reportError(.maskCreationFailed, debug: "Failed to create mask")
                return
            }
            
            guard let maskImage = apply(mask: fakeMask, to: fakeMask),
                  let outputImage = apply(mask: maskImage, to: inputImage),
                  let renderedResult = convertToUIImage(ciImage: outputImage),
                  let renderedMask = convertToUIImage(ciImage: maskImage) else {
                reportError(.maskCreationFailed, debug: "Failed to create mask")
                return
            }

            resultImage = renderedResult
            mask = renderedMask
            self.maskImage = mask
            self.resultImage = resultImage
        }
    }
    
    private func createMask(from inputImage: CIImage) -> CIImage? {
        do {
            return try maskingService.makeMask(from: inputImage)
        } catch {
            reportError(.maskCreationFailed, debug: "Mask 생성 실패: \(error)")
            return nil
        }
    }
    
    private func apply(mask: CIImage, to image: CIImage) -> CIImage? {
        
        let filter = CIFilter.blendWithMask()
        filter.inputImage = image
        filter.maskImage = mask
        filter.backgroundImage = CIImage.empty()
        return filter.outputImage
    }
    
    private func convertToUIImage(ciImage: CIImage) -> UIImage? {
        
        guard let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent) else {
            reportError(.imageRenderingFailed, debug: "Failed to render CGImage")
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    func appendMaskImage(_ inputImage: UIImage?) {
        if let image = inputImage {
            if indexOfMask < maskImageList.count - 1 {
                for _ in indexOfMask+1..<maskImageList.count {
                    maskImageList.removeLast()
                }
            }
            maskImageList.append(image)
            indexOfMask += 1
            print("\(indexOfMask)")
            
        }
        maskImage = maskImageList[indexOfMask]
        opacity = 0.4
        maskColor = .pink
    }
    
}
