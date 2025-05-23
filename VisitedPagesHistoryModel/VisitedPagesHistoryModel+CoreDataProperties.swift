import Foundation
import CoreData

extension VisitedPagesHistoryModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisitedPagesHistoryModel> {
        return NSFetchRequest<VisitedPagesHistoryModel>(entityName: visitedPagesHistoryModelName)
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var title: String
    @NSManaged public var updatedAt: Date
    @NSManaged public var url: URL
    @NSManaged public var timesUpdated: Int64
    @NSManaged public var timesCreatedNewTabWithThisPage: Int64
    @NSManaged public var timesSwitchedToWhileHavingHostTabOpen: Int64

}

extension VisitedPagesHistoryModel : Identifiable {

}
