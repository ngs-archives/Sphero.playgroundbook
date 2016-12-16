//
//  Command.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import Foundation
import UIKit

public protocol Command {
    var answer: Bool { get }
    var resetTimeout: Bool { get }
    var deviceID: UInt8 { get }
    var commandID: UInt8 { get }
    var payload: Data? { get }
}

extension Command {
    public var answer: Bool {
        return true
    }

    public var resetTimeout: Bool {
        return true
    }

    public var sop2: UInt8 {
        var value: UInt8 = 0b11111100
        if answer {
            value |= 1 << 0
        }
        if resetTimeout {
            value |= 1 << 1
        }

        return value
    }

    internal func dataForPacket(sequenceNumber: UInt8 = 0) -> Data {
        let payloadLength = payload?.count ?? 0
        var zero: UInt8 = 0
        var data = Data(bytes: &zero, count: 6)

        data[0] = 0b11111111
        data[1] = sop2
        data[2] = deviceID
        data[3] = commandID
        data[4] = sequenceNumber
        data[5] = UInt8(payloadLength + 1)

        if let payload = payload {
            data.append(payload)
        }

        let checksumTarget = data[2 ..< data.count]

        var checksum: UInt8 = 0
        for byte in checksumTarget {
            checksum = checksum &+ byte
        }
        checksum = ~checksum

        data.append(Data(bytes: [checksum]))

        return data
    }
}

public protocol CoreCommand: Command {}

extension CoreCommand {
    public var deviceID: UInt8 {
        return 0x00
    }
}

public protocol SpheroCommand: Command {}

extension SpheroCommand {
    public var deviceID: UInt8 {
        return 0x02
    }
}

public struct PingCommand: CoreCommand {
    public let commandID: UInt8 = 0x01
    public let payload: Data? = nil

    static func response(sequenceNumber: UInt8 = 0) -> Data {
        var bytes: [UInt8] = [0xff, 0xff, 0x00, sequenceNumber, 0x01]

        let checksumTarget = bytes[2 ..< bytes.count]
        var checksum: UInt8 = 0
        for byte in checksumTarget {
            checksum = checksum &+ byte
        }
        checksum = ~checksum
        bytes.append(checksum)

        return Data(bytes: bytes)
    }
}

public struct UpdateHeadingCommand: SpheroCommand {
    public let commandID: UInt8 = 0x01

    public var heading: UInt16
    public init(heading: UInt16) {
        self.heading = heading
    }

    public var payload: Data? {
        let clampedHeading = (heading % 360)
        let headingLeft = UInt8((clampedHeading >> 8) & 0xff)
        let headingRight = UInt8(clampedHeading & 0xff)

        return Data(bytes: [headingLeft, headingRight])
    }
}

public struct SetLEDColor: SpheroCommand {
    public let commandID: UInt8 = 0x20

    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var save: Bool

    public init(red: UInt8, green: UInt8, blue: UInt8, save: Bool = false) {
        self.red = red
        self.green = green
        self.blue = blue
        self.save = save
    }

    public init(color: UIColor, save: Bool = false) {
        var redComponent: CGFloat = 0
        var greenComponent: CGFloat = 0
        var blueComponent: CGFloat = 0

        if color.getRed(&redComponent, green: &greenComponent, blue: &blueComponent, alpha: nil) {
            self.red = UInt8(0xff * redComponent)
            self.green = UInt8(0xff * greenComponent)
            self.blue = UInt8(0xff * blueComponent)
        }
        else {
            fatalError("Passed in color cannot be converted to RGB space!")
        }
        self.save = save
    }

    public var payload: Data? {
        let data = Data(bytes: [red, green, blue, save ? 1 : 0])
        return data
    }
}

public struct SetBackLEDBrightness: SpheroCommand {
    public let commandID: UInt8 = 0x21

    public var brightness: UInt8

    public init(brightness: UInt8) {
        self.brightness = brightness
    }

    public var payload: Data? {
        let data = Data(bytes: [brightness])
        return data
    }
}

public struct Roll: SpheroCommand {
    public let commandID: UInt8 = 0x30

    public var speed: UInt8
    public var heading: UInt16
    public var state: UInt8

    public init(speed: UInt8, heading: UInt16, state: UInt8 = 1) {
        self.speed = speed
        self.heading = heading
        self.state = state
    }

    public var payload: Data? {
        let clampedHeading = (heading % 360)
        let headingLeft = UInt8((clampedHeading >> 8) & 0xff)
        let headingRight = UInt8(clampedHeading & 0xff)

        return Data(bytes: [speed, headingLeft, headingRight, state])
    }
}
