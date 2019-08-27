//
//  WaypointEntity.swift
//  HEREMapsExample
//
//  Created by Vladyslav on 8/27/19.
//  Copyright © 2019 Vladyslav Kudelia. All rights reserved.
//

import NMAKit

class WaypointEntity {
    let name: String
    let position: NMAGeoCoordinates
    var isCheck: Bool
    
    init(name: String, position: NMAGeoCoordinates, isCheck: Bool) {
        self.name = name
        self.position = position
        self.isCheck = isCheck
    }
}
