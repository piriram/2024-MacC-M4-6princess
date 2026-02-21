import Foundation
import CoreData

enum StoreImageSortOption {
    case createdDateAscending
    case orderAscending
}

struct StoreImageRecord {
    let id: UUID
    let imageData: Data?
}

protocol StoreImagePersisting {
    func fetchRecords(sort: StoreImageSortOption) throws -> [StoreImageRecord]
    func fetchImageData(for id: UUID) throws -> Data?
    func deleteImage(id: UUID) throws
    func deleteImages(ids: Set<UUID>) throws
}

final class StoreImagePersistenceService: StoreImagePersisting {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchRecords(sort: StoreImageSortOption) throws -> [StoreImageRecord] {
        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        switch sort {
        case .createdDateAscending:
            request.sortDescriptors = [NSSortDescriptor(keyPath: \StoreImages.createdDate, ascending: true)]
        case .orderAscending:
            request.sortDescriptors = [NSSortDescriptor(keyPath: \StoreImages.order, ascending: true)]
        }

        let storedImages = try context.fetch(request)
        return storedImages.compactMap { storeImage in
            guard let id = storeImage.uuid else { return nil }
            return StoreImageRecord(id: id, imageData: storeImage.image)
        }
    }

    func fetchImageData(for id: UUID) throws -> Data? {
        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first?.image
    }

    func deleteImage(id: UUID) throws {
        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let target = try context.fetch(request).first else { return }
        context.delete(target)
        try context.save()
    }

    func deleteImages(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }

        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        request.predicate = NSPredicate(format: "uuid IN %@", ids)

        let targets = try context.fetch(request)
        for target in targets {
            context.delete(target)
        }

        try context.save()
    }
}
