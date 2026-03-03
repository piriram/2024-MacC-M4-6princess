import SwiftUI
import CoreData

class MFDetailViewModel: ObservableObject {
    @Published var selectedImageId: UUID?
    @Published var isDeleteAlertDetail = false
    @Published var imageDataArray: [(id: UUID, data: Data)] = []
    @Published var appError: AppError?

    private var storeImageService: StoreImagePersisting?

    init(storeImageService: StoreImagePersisting? = nil) {
        self.storeImageService = storeImageService
    }

    private func reportError(_ error: AppError, debug: String? = nil) {
        appError = error
        if let debug {
            print(debug)
        }
    }

    func configure(context: NSManagedObjectContext, selectedId: UUID?) {
        if storeImageService == nil {
            self.storeImageService = StoreImagePersistenceService(context: context)
        }
        self.selectedImageId = selectedId
        loadImages()
    }

    /// Core Data에서 이미지 데이터를 로드하여 imageDataArray를 채움
    func loadImages() {
        guard let service = storeImageService else { return }

        do {
            let records = try service.fetchRecords(sort: .orderAscending)
            imageDataArray = records.compactMap { record in
                guard let imageData = record.imageData else { return nil }
                return (id: record.id, data: imageData)
            }
        } catch {
            reportError(.coreDataFetchFailed, debug: "이미지 로드 실패: \(error)")
        }
    }

    func loadOriginalImageData() -> Data? {
        guard let service = storeImageService,
              let id = selectedImageId else { return nil }

        do {
            return try service.fetchImageData(for: id)
        } catch {
            reportError(.coreDataFetchFailed, debug: "이미지 로딩 실패: \(error)")
            return nil
        }
    }

    func deleteSelectedImage(completion: @escaping () -> Void) {
        guard let service = storeImageService,
              let id = selectedImageId else { return }

        do {
            try service.deleteImage(id: id)
            loadImages()
            completion()
        } catch {
            reportError(.coreDataSaveFailed, debug: "삭제 실패: \(error)")
        }
    }


    func loadSubjectsForModify(frameId: UUID?, imageModel: ImageListModel) -> Bool {
        imageModel.imageList.removeAll()

        guard let service = storeImageService,
              let frameId else {
            return false
        }

        do {
            let subjectRecords = try service.fetchSubjectRecords(for: frameId)

            for (index, subject) in subjectRecords.enumerated() {
                let newImage = SubjectImage()

                if let image = subject.subImage,
                   let originImage = subject.originalImage,
                   let mask = subject.maskImage {
                    newImage.image = UIImage(data: image)
                    newImage.originalImage = UIImage(data: originImage)
                    newImage.maskImage = UIImage(data: mask)
                } else if let text = subject.text,
                          let originText = subject.originalText {
                    newImage.text = UIImage(data: text)
                    newImage.textStyle = TextStyle(
                        attributedString: NSAttributedString(string: ""),
                        txt: originText,
                        font: .modern,
                        color: ColorPreset.colorPallete[0],
                        alignment: .center,
                        fontSize: 20
                    )
                } else if let sticker = subject.sticker {
                    newImage.sticker = UIImage(data: sticker)
                }

                newImage.scale = subject.scale
                newImage.angle = Angle.degrees(subject.angle)
                newImage.offset = CGSize(width: subject.x, height: subject.y)
                newImage.isTapped = index == subjectRecords.count - 1

                imageModel.imageList.append(newImage)
            }

            return true
        } catch {
            reportError(.coreDataFetchFailed, debug: "Subject 로딩 실패: \(error)")
            return false
        }
    }

    /// 선택된 이미지의 인덱스를 반환
    func indexOfSelectedImage() -> Int? {
        guard let selectedId = selectedImageId else { return nil }
        let totalCount = imageDataArray.count
        return imageDataArray.firstIndex(where: { $0.id == selectedId }).map { totalCount - $0 }
    }

    /// 전체 이미지 개수를 반환
    func totalImageCount() -> Int {
        return imageDataArray.count
    }
}
