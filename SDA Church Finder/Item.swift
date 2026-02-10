//
//  Item.swift
//  SDA Church Finder
//
//  Created by Kyle Slingo on 2/10/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
