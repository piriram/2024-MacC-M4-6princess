import XCTest
import CoreData
@testable import _024_MacC_M4_6princess

final class StoreImagePersistenceServiceTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var sut: StoreImagePersistenceService!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
        sut = StoreImagePersistenceService(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    func testFetchRecordsSortedByCreatedDateAscending() throws {
        let firstId = UUID()
        let secondId = UUID()

        insertStoreImage(id: secondId, createdDate: Date(timeIntervalSince1970: 20))
        insertStoreImage(id: firstId, createdDate: Date(timeIntervalSince1970: 10))

        let records = try sut.fetchRecords(sort: .createdDateAscending)

        XCTAssertEqual(records.map(\.id), [firstId, secondId])
    }

    func testDeleteImageRemovesTargetRecord() throws {
        let keepId = UUID()
        let deleteId = UUID()

        insertStoreImage(id: keepId, createdDate: Date())
        insertStoreImage(id: deleteId, createdDate: Date().addingTimeInterval(1))

        try sut.deleteImage(id: deleteId)
        let records = try sut.fetchRecords(sort: .createdDateAscending)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, keepId)
    }

    func testDeleteImagesAndReturnCountReturnsDeletedCount() throws {
        let keepId = UUID()
        let deleteId1 = UUID()
        let deleteId2 = UUID()

        insertStoreImage(id: keepId, createdDate: Date())
        insertStoreImage(id: deleteId1, createdDate: Date().addingTimeInterval(1))
        insertStoreImage(id: deleteId2, createdDate: Date().addingTimeInterval(2))

        let deletedCount = try sut.deleteImagesAndReturnCount(ids: [deleteId1, deleteId2])
        let records = try sut.fetchRecords(sort: .createdDateAscending)

        XCTAssertEqual(deletedCount, 2)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, keepId)
    }

    private func insertStoreImage(id: UUID, createdDate: Date) {
        let image = StoreImages(context: context)
        image.uuid = id
        image.createdDate = createdDate
        image.image = Data([0x01, 0x02])

        do {
            try context.save()
        } catch {
            XCTFail("failed to save test data: \(error)")
        }
    }
}
