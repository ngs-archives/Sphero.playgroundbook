//
//  CBUUID+SpheroUUIDs.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

extension CBUUID {
    // Sphero services
    @nonobjc static let bleService = CBUUID(string: "22bb746f-2bb0-7554-2d6f-726568705327")
    @nonobjc static let robotControlService = CBUUID(string: "22bb746f-2ba0-7554-2d6f-726568705327")

    // BLE service characteristics
    @nonobjc static let wakeCharacteristic = CBUUID(string: "22bb746f-2bbf-7554-2d6f-726568705327")
    @nonobjc static let txPowerCharacteristic = CBUUID(string: "22bb746f-2bb2-7554-2d6f-726568705327")
    @nonobjc static let antiDoSCharacteristic = CBUUID(string: "22bb746f-2bbd-7554-2d6f-726568705327")

    // Robot control service characteristics
    @nonobjc static let commandsCharacteristic = CBUUID(string: "22bb746f-2ba1-7554-2d6f-726568705327")
    @nonobjc static let responseCharacteristic = CBUUID(string: "22bb746f-2ba6-7554-2d6f-726568705327")
}
