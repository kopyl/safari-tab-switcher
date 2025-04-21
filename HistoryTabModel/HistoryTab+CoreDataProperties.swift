//
//  HistoryTab+CoreDataProperties.swift
//  Tab Finder
//
//  Created by Oleh Kopyl on 21.04.2025.
//
//

import Foundation
import CoreData


extension HistoryTab {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HistoryTab> {
        return NSFetchRequest<HistoryTab>(entityName: "HistoryTab")
    }

    @NSManaged public var data: Data?

}

extension HistoryTab : Identifiable {

}
