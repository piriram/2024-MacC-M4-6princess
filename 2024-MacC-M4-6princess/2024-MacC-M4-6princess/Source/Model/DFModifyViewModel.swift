import SwiftUI
import Vision
import VisionKit
import CoreData

@MainActor
class DFModifyViewModel: ObservableObject {
    
    
    @Published var magnifyScale = 1.0
    @Published var lastScale = 1.0
    @Published var current: Angle = .degrees(0)
    @Published var draggedOffSet: CGSize = .zero
    @Published var accumulatedOffSet: CGSize = .zero
    @Published var angle: Angle = .degrees(0)
    
    @Published var btnOpacity: Double = 0.0
    
    @Published var showCamera: Bool = false
    @Published var showImagePickerView: Bool = false
    
    @Published var isPushedSaveBtn: Bool = false
    @Published var saveStateText: String = ""
    @Published var isTappedImage: Bool = false
    
    @Published var outputImage: UIImage?
    @Published var indexOfImageList: Int = 0
    @Published var imageList: [SubjectImage] = []
    @Published var imageHistory: [SubjectImage] = []
    
    @Published var frameImage: UIImage?
    
    @Published var showTextView: Bool = false
    //    @Published var showTextModifyView: Bool = false
    @Published var showStickerSheet: Bool = false
    
    @Published var isAlert: Bool = false
    
    @Published var modelList: [SubjectImage] = []
    
    @Published var showAgain: Bool = false
    @Published var appError: AppError?
    
    /// 레이어 변경 관련 변수
    @Published var isPressedUp = false
    @Published var isPressedDown = false
    @Published var selectedSubject: SubjectImage? = nil
    @Published var selectedIndex: Int? = nil
    
    /// 스티커 변수
    var selectedStickerTab = StickerTab.bubble
    
    @Published var style:TextStyle = TextStyle(attributedString: NSAttributedString(string: ""), txt: "", font: .modern, color: ColorPreset.colorPallete[0], alignment: .center, fontSize: 20 )
    private let imagePipeline: ImagePipelining = ImagePipelineService()
    
    private func reportError(_ error: AppError, debug: String? = nil) {
        appError = error
        if let debug {
            print(debug)
        }
    }

    func backgroundGesture() -> some Gesture {
        
        MagnifyGesture()
            .onChanged { value in
                if let subject = self.modelList.first, subject.isTapped {
                    self.setScaleVolume(value.magnification, subject: subject)
                }
            }
            .onEnded { value in
                if let subject = self.modelList.first, subject.isTapped {
                    self.setScaleValue(minimum: 0.1, maximum: 10, subject: subject)
                }
                
            }
            .simultaneously(with: DragGesture()
                .onChanged({ value in
                    
                    if let subject = self.modelList.first, subject.isTapped {
                        self.dragGestureTask(subject: subject, changed: value.translation)
                    }
                })
                    .onEnded({ value in
                        
                        if let subject = self.modelList.first {
                            
                            self.accumulatedOffSet = .zero
                            self.modelListControl(subject: subject)
                            subject.isTapped = true
                        }
                    })
            )
            .simultaneously(with: RotateGesture()
                .onChanged({ value in
                    
                    if let subject = self.modelList.first, subject.isTapped {
                        if self.current == .zero {
                            self.current = subject.getAngle()
                        }
                        self.angle = value.rotation + self.current
                        subject.setAngle(angle: self.angle)
                    }
                })
                    .onEnded({ value in
                        self.current = .zero
                    })
            )
        
    }
    
    func modelListControl(subject: SubjectImage) {
        
        modelList.append(subject)
        
        if modelList.count == 2 {
            modelList[0].isTapped = false
            modelList.removeFirst()
        }
    }
    
    func setScaleValue(minimum: CGFloat, maximum: CGFloat, subject: SubjectImage) {
        
        if subject.getScale() < minimum {
            subject.setScale(scale: minimum)
            
        } else if subject.getScale() > maximum {
            subject.setScale(scale: maximum)
        }
        lastScale = 1.0
        
    }
    
    ///스케일의 변화량(속도) 을 동일하게 하기 위한 메소드
    func setScaleVolume(_ magnify: CGFloat, subject: SubjectImage) {
        
        let scaleVolume = magnify / lastScale
        subject.scale *= scaleVolume
        lastScale = magnify
    }
    
    func dragGestureTask(subject: SubjectImage, changed: CGSize) {
        
        if accumulatedOffSet == .zero {
            accumulatedOffSet = subject.getOffset()
        }
        draggedOffSet.width = accumulatedOffSet.width + changed.width
        draggedOffSet.height = accumulatedOffSet.height + changed.height
        subject.setOffset(offset: draggedOffSet)
    }
    
    func setSizeCompute(image: UIImage, realImage: UIImage) -> CGSize {
        
        let width = image.size.width / scaleCompute(realImage)
        let height = image.size.height / scaleCompute(realImage)
        
        return .init(width: width, height: height)
    }
    
    
    func saveImage(view: some View, inputImage: UIImage, context: NSManagedObjectContext, imageModel: ImageListModel, completionHandler: @escaping () -> Void) {
        
        btnOpacity = 1
        
        Task {
            // 저장 완료 메시지 숨기기
            frameImage = imagePipeline.renderImage(
                content: view.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 4/3),
                scale: UIScreen.main.scale + 1
            )
            addImage(albumImageData: frameImage?.pngData(), context: context, subjects: imageModel)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completionHandler()
        }
        
    }
    
    func updateImage(view: some View, frameManager: FrameManager, viewContext: NSManagedObjectContext, imageModel: ImageListModel, completionHandler: @escaping () -> Void) {
        
        guard let frameId = frameManager.updateFrame else {
            frameManager.resultImage = nil
            return
        }
        
        btnOpacity = 1
        
        let fetchRequest: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", frameId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        
        Task {
            // 저장 완료 메시지 숨기기
            frameImage = imagePipeline.renderImage(
                content: view.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 4/3),
                scale: UIScreen.main.scale
            )

            do {
                let results = try viewContext.fetch(fetchRequest)
                if let storedImage = results.first {
                    storedImage.image = frameImage?.pngData()
                    
                    if let subjects = storedImage.subjects?.allObjects as? [Subject] {
                        for i in subjects {
                            storedImage.removeFromSubjects(i)
                        }
                    }
                    
                    for i in imageModel.imageList {
                        
                        let newSubject = Subject(context: viewContext)
                        
                        if let image = i.image, let originImage = i.originalImage, let mask = i.maskImage {
                            newSubject.subImage = image.pngData()
                            newSubject.originalImage = originImage.pngData()
                            newSubject.maskImage = mask.pngData()
                            
                            print("이미지 저장됨")
                        } else if let text = i.text, let originText = i.textStyle?.txt {
                            newSubject.text = text.pngData()
                            newSubject.originalText = originText
                            print("텍스트 저장됨")
                        } else if let sticker = i.sticker {
                            newSubject.sticker = sticker.pngData()
                            print("스티커 저장됨")
                        }
                        newSubject.angle = i.angle.degrees
                        newSubject.scale = i.scale
                        newSubject.x = i.offset.width
                        newSubject.y = i.offset.height
                        newSubject.uuid = UUID()
                        
                        storedImage.addToSubjects(newSubject)
                        
                    }
                }
                saveContext(context: viewContext)
                
            } catch {
                reportError(.coreDataFetchFailed, debug: "Error fetching frame: \(error)")
                frameManager.resultImage = nil
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completionHandler()
        }
    }
    
    func saveContext(context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            reportError(.coreDataSaveFailed, debug: "Error saving managed object context: \(error)")
        }
    }
    func addImage(albumImageData: Data?, context: NSManagedObjectContext, subjects: ImageListModel) {
        
        
        let newImage = StoreImages(context: context)
        newImage.image = albumImageData
        newImage.uuid = UUID()
        newImage.isSelected = false
        newImage.createdDate = Date() //최근 프레임 찾는 용도
        
        for i in subjects.imageList {
            let newSubject = Subject(context: context)
            
            if let image = i.image, let originImage = i.originalImage, let mask = i.maskImage {
                newSubject.subImage = image.pngData()
                newSubject.originalImage = originImage.pngData()
                newSubject.maskImage = mask.pngData()
                
                print("이미지 저장됨")
            } else if let text = i.text, let originText = i.textStyle?.txt {
                newSubject.text = text.pngData()
                newSubject.originalText = originText
                print("텍스트 저장됨")
            } else if let sticker = i.sticker {
                newSubject.sticker = sticker.pngData()
                print("스티커 저장됨")
            }
            newSubject.angle = i.angle.degrees
            newSubject.scale = i.scale
            newSubject.x = i.offset.width
            newSubject.y = i.offset.height
            newSubject.uuid = UUID()
            
            newImage.addToSubjects(newSubject)
            
        }
        saveContext(context: context)
    }
    
    func scaleCompute(_ image: UIImage) -> CGFloat {
        imagePipeline.displayScale(for: image, screenWidth: UIScreen.main.bounds.width)
    }
    
    func makeImageList() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            var inputImage = SubjectImage()
            
            inputImage.image = self.outputImage
            
            self.imageHistory.append(inputImage)
        }
    }
    
    func makeImage(view: some View, image: UIImage) -> UIImage? {
        
        if imageList.isEmpty {
            imageList.append(SubjectImage())
            indexOfImageList = 0
        }

        guard let renderedImage = imagePipeline.renderImage(content: view, scale: scaleCompute(image)) else { return nil }

        if indexOfImageList < imageList.count - 1 {
            for _ in indexOfImageList+1..<imageList.count {
                imageList.removeLast()
            }
        }

        guard imageList.indices.contains(indexOfImageList) else { return nil }
        imageList[indexOfImageList].image = renderedImage
        indexOfImageList += 1

        if imageList.count == indexOfImageList {
            imageList.append(SubjectImage())
        }

        return renderedImage
    }
    
    
    //    func addImage(albumImageData: Data?, subjectImageData: Data?, context: NSManagedObjectContext) {
    //
    //        let newImage = StoreImages(context: context)
    //
    //        newImage.image = albumImageData
    //        newImage.subjectImage = subjectImageData
    //        newImage.uuid = UUID()
    //        newImage.isSelected = false
    //        newImage.angle = angle.degrees
    //        newImage.x = draggedOffSet.width
    //        newImage.y = draggedOffSet.height
    //        newImage.scale = magnifyScale
    //
    //        saveContext(context: context)
    //    }
    
    
    //    func reDo() {
    //
    //        if indexOfImageList > 0 {
    //            indexOfImageList -= 1
    //            angle = imageList[indexOfImageList].angle
    //            current = imageList[indexOfImageList].angle
    //            magnifyScale = imageList[indexOfImageList].scale
    //            draggedOffSet = imageList[indexOfImageList].offSet
    //        }
    //    }
    //
    //    func unDo() {
    //
    //        if imageList.count - 1 > indexOfImageList {
    //            indexOfImageList += 1
    //            angle = imageList[indexOfImageList].angle
    //            current = imageList[indexOfImageList].angle
    //            magnifyScale = imageList[indexOfImageList].scale
    //            draggedOffSet = imageList[indexOfImageList].offSet
    //        }
    //    }
    
}
