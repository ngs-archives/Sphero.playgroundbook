//
//  Sphero.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

public class Sphero {
    private let core: Core

    init(core: Core) {
        self.core = core
    }

    public func send(_ command: Command) {
        core.send(command)
    }

    /// A class which defines the core of a Sphero object.
    /// This is separate so that the CBPeripheralDelegate conformance doesn't show up in code completion with the Sphero class.
    class Core: NSObject, CBPeripheralDelegate {

        private let peripheral: CBPeripheral

        init(peripheral: CBPeripheral) {
            assert(peripheral.state == .connected, "The peripheral must be connected!")
            self.peripheral = peripheral
            super.init()
            peripheral.delegate = self
        }

        func send(_ command: Command) {
            peripheral.writeValue(command.dataForPacket(), for: commandsCharacteristic, type: .withResponse)
        }

        var preparationCallback: ((_ didPrepareConnection: Bool, _ error: Error?) -> Void)?

        func prepareConnection(callback: @escaping (_ didPrepareConnection: Bool, _ error: Error?) -> Void) {
            assert(preparationCallback == nil)
            preparationCallback = callback
            peripheral.discoverServices([.robotControlService, .bleService])
        }

        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let error = error {
                preparationCallback?(false, error as Error)
                preparationCallback = nil
                return
            }

            guard let services = peripheral.services else { return }

            for service in services {
                switch service.uuid {
                case CBUUID.bleService:
                    peripheral.discoverCharacteristics([.wakeCharacteristic, .txPowerCharacteristic, .antiDoSCharacteristic], for: service)
                case CBUUID.robotControlService:
                    peripheral.discoverCharacteristics([.commandsCharacteristic, .responseCharacteristic], for: service)
                default:
                    // This is a service we don't care about. Ignore it.
                    continue
                }
            }
        }

        private var wakeCharacteristic: CBCharacteristic!
        private var txPowerCharacteristic: CBCharacteristic!
        private var antiDoSCharacteristic: CBCharacteristic!
        private var commandsCharacteristic: CBCharacteristic!
        private var responseCharacteristic: CBCharacteristic!

        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if let error = error {
                preparationCallback?(false, error as Error)
                preparationCallback = nil
                return
            }

            guard let characteristics = service.characteristics else {
                return
            }

            for characteristic in characteristics {
                switch characteristic.uuid {
                case CBUUID.wakeCharacteristic:
                    wakeCharacteristic = characteristic
                case CBUUID.txPowerCharacteristic:
                    txPowerCharacteristic = characteristic
                case CBUUID.antiDoSCharacteristic:
                    antiDoSCharacteristic = characteristic
                case CBUUID.commandsCharacteristic:
                    commandsCharacteristic = characteristic
                case CBUUID.responseCharacteristic:
                    responseCharacteristic = characteristic
                default:
                    // This is a characteristic we don't care about. Ignore it.
                    continue
                }
            }

            if wakeCharacteristic != nil && txPowerCharacteristic != nil && antiDoSCharacteristic != nil && commandsCharacteristic != nil && responseCharacteristic != nil {
                peripheral.writeValue("011i3".data(using: String.Encoding.ascii)!, for: antiDoSCharacteristic, type: .withResponse)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if characteristic === responseCharacteristic {
                if let error = error {
                    preparationCallback?(false, error as Error)
                    preparationCallback = nil
                    return
                }

                // Send a ping to try to start the connection.
                send(PingCommand())
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                preparationCallback?(false, error as Error)
                preparationCallback = nil
                return
            }

            if characteristic === commandsCharacteristic {}
            else if characteristic === antiDoSCharacteristic {
                peripheral.writeValue(Data(bytes: [7]), for: txPowerCharacteristic, type: .withResponse)
            }
            else if characteristic === txPowerCharacteristic {
                peripheral.writeValue(Data(bytes: [1]), for: wakeCharacteristic, type: .withResponse)
            }
            else if characteristic === wakeCharacteristic {
                peripheral.setNotifyValue(true, for: responseCharacteristic)
            }
        }

        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                preparationCallback?(false, error as Error)
                preparationCallback = nil
                return
            }

            guard characteristic === responseCharacteristic, let response = characteristic.value else { return }

            if preparationCallback != nil {
                if response == PingCommand.response() {
                    // This is the ping result. Finish preparing as our connection is fully ready.
                    preparationCallback?(true, nil)
                    preparationCallback = nil
                }
                else {
                    // Send a ping to try to start the connection.
                    send(PingCommand())
                }
            }
        }
    }
}
