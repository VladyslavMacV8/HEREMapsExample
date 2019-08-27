//
//  Constants.swift
//  HEREMapsExample
//
//  Created by Vladyslav Kudelia on 8/26/19.
//  Copyright © 2019 Vladyslav Kudelia. All rights reserved.
//

import Foundation

struct Constants {
    static let appId = ""
    static let appCode = ""
    static let licenseKey = ""
    
    static let firstAddress = "Enter first address"
    static let secondAddress = "Enter second address"
    static let thirdAddress = "Enter third address"
    static let addressesDone = "Address are ready"
}

enum PlacesState {
    case first
    case second
    case third
    case done
}

enum AppState {
    case config
    case route
}
