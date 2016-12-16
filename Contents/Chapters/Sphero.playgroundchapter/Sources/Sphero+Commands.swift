//
//  Sphero+Commands.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import UIKit

extension Sphero {
    public func setColor(_ color: UIColor) {
        send(SetLEDColor(color: color))
    }

    public func setBackLightBrightness(_ brightness: UInt8) {
        send(SetBackLEDBrightness(brightness: brightness))
    }

    public func roll(speed: UInt8, heading: UInt16) {
        send(Roll(speed: speed, heading: heading))
    }
}
