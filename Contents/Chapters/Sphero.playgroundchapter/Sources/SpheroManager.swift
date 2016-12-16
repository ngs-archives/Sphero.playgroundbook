//
//  SpheroManager.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

struct SpheroDescription {
    let name: String?
    let identifier: UUID
    let rssi: Int
}

private struct ConnectingSphero {
    let peripheral: CBPeripheral
    let spheroDescription: SpheroDescription
}

final class SpheroManager: NSObject, CBCentralManagerDelegate {
    private var queue = DispatchQueue(label: "SpheroManager queue")

    private lazy var central: CBCentralManager = CBCentralManager(delegate: self, queue: self.queue)

    weak var delegate: SpheroManagerDelegate? = nil

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if shouldBeScanning {
                scanForDevices()
            }
        case .poweredOff:
            stopScanning()
        case .resetting:
            break
        case .unauthorized, .unknown, .unsupported:
            // TODO: handle these cases as errors.
            break
        }
    }

    private var shouldBeScanning = false

    func scanForDevices() {
        // Indicate that we should be scanning so delegate callbacks will start a scan if we can't right now.
        shouldBeScanning = true

        // This method can only do anything if the CBCentralManager is poweredOn.
        // It doesn't need to do anything else if it's already scanning.
        // If either of those things are true, return early.
        guard central.state == .poweredOn && !central.isScanning else { return }

        central.scanForPeripherals(withServices: [.robotControlService], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func stopScanning() {
        // Indicate that we shouldn't be scanning so delegate callbacks won't start a scan if we're not scanning right now.
        shouldBeScanning = false

        // This method can only do anything if the CBCentralManager is currently scanning.
        // If we aren't, then this method can just return without doing anything.
        guard central.isScanning else { return }

        central.stopScan()
    }

    enum ConnectionError: Error {
        case unknownSphero
    }

    func connectTo(_ spheroDescription: SpheroDescription) {
        queue.async {
            guard let peripheral = self.discoveredPeripherals.removeValue(forKey: spheroDescription.identifier) else {
                fatalError("Asked to connect to a peripheral which was not discovered or to which a connection was previously established")
            }

            guard self.connectingSpheros.updateValue(ConnectingSphero(peripheral: peripheral, spheroDescription: spheroDescription), forKey: peripheral.identifier) == nil else {
                fatalError("Asked to connect to a peripheral to which we were already connecting")
            }

            self.central.connect(peripheral, options: nil)
        }
    }

    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        discoveredPeripherals[peripheral.identifier] = peripheral

        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
            self.delegate?.spheroManager(self, didDiscover: SpheroDescription(name: peripheral.name, identifier: peripheral.identifier, rssi: rssi.intValue))
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    private var connectingSpheros: [UUID: ConnectingSphero] = [:]

    private var connectedSpheroCores: [UUID: Sphero.Core] = [:]

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let connectingSphero = connectingSpheros.removeValue(forKey: peripheral.identifier) else {
            fatalError("Connected to a peripheral which we weren't tracking")
        }

        let spheroCore = Sphero.Core(peripheral: peripheral)

        guard connectedSpheroCores.updateValue(spheroCore, forKey: peripheral.identifier) == nil else {
            fatalError("Connected to a peripheral to which we were already connected")
        }

        spheroCore.prepareConnection { didPrepareConnection, error in
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
                if didPrepareConnection {
                    self.delegate?.spheroManager(self, didConnect: Sphero(core: spheroCore))
                }
                else {
                    central.cancelPeripheralConnection(peripheral)
                    self.delegate?.spheroManager(self, didFailToConnect: connectingSphero.spheroDescription, error: error)
                }
            }
            CFRunLoopWakeUp(CFRunLoopGetMain())
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let connectingSphero = connectingSpheros.removeValue(forKey: peripheral.identifier) else {
            fatalError("Failed to connect to a peripheral which we weren't tracking")
        }

        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
            self.delegate?.spheroManager(self, didFailToConnect: connectingSphero.spheroDescription, error: error as Error?)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard connectedSpheroCores.removeValue(forKey: peripheral.identifier) != nil else {
            fatalError("Disconnected from a peripheral which we weren't tracking")
        }
    }
}

protocol SpheroManagerDelegate: class {
    func spheroManager(_ spheroManager: SpheroManager, didDiscover spheroDescription: SpheroDescription)

    func spheroManager(_ spheroManager: SpheroManager, didConnect sphero: Sphero)

    func spheroManager(_ spheroManager: SpheroManager, didFailToConnect spheroDescription: SpheroDescription, error: Error?)
}

extension SpheroManagerDelegate {
    func spheroManager(_ spheroManager: SpheroManager, didDiscover spheroDescription: SpheroDescription) {}
    func spheroManager(_ spheroManager: SpheroManager, didConnect sphero: Sphero) {}
    func spheroManager(_ spheroManager: SpheroManager, didFailToConnect spheroDescription: SpheroDescription, error: Error?) {}
}
