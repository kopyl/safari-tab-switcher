//
//  VisitedPagesHistoryModel+CoreDataProperties.swift
//  Tab Finder
//
//  Created by Oleh Kopyl on 21.04.2025.
//
//

import Foundation
import CoreData


extension VisitedPagesHistoryModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisitedPagesHistoryModel> {
        return NSFetchRequest<VisitedPagesHistoryModel>(entityName: "VisitedPagesHistoryModel")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var title: String
    @NSManaged public var updatedAt: Date
    @NSManaged public var url: URL

}

extension VisitedPagesHistoryModel : Identifiable {

}
