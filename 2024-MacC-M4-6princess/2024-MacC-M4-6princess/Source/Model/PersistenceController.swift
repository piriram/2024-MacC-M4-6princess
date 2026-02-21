import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ImageModel") // .xcdatamodeld 파일명
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                assertionFailure("Core Data store failed to load: \(error.localizedDescription)")
                print("Core Data store failed to load: \(error.localizedDescription)")
                return
            }
            
            #if DEBUG
            // CoreData 파일 위치 확인
            if let url = description.url {
                print("Core Data store URL: \(url)")
            }
            #endif
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
