//
//  Sphero+Connection.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import Foundation

private let sharedManager: SpheroManager = SpheroManager()

extension Sphero {
    public class func named(_ name: String, timeout: TimeInterval = 15) -> Sphero? {
        class Delegate: SpheroManagerDelegate {
            var sphero: Sphero? = nil

            let name: String
            let timeout: TimeInterval

            init(name: String, timeout: TimeInterval) {
                self.name = name
                self.timeout = timeout
            }

            func spheroManager(_ spheroManager: SpheroManager, didDiscover spheroDescription: SpheroDescription) {
                guard spheroDescription.name == self.name else { return }

                spheroManager.connectTo(spheroDescription)
            }

            func spheroManager(_ spheroManager: SpheroManager, didConnect sphero: Sphero) {
                self.sphero = sphero
                CFRunLoopStop(CFRunLoopGetMain())
            }

            func spheroManager(_ spheroManager: SpheroManager, didFailToConnect spheroDescription: SpheroDescription, error: Error?) {
                self.sphero = nil
                CFRunLoopStop(CFRunLoopGetMain())
            }

            var timer: Timer?

            @objc func timerFired(_ timer: Timer) {
                self.timer = nil
                CFRunLoopStop(CFRunLoopGetMain())
            }

            func waitForConnection() {
                sharedManager.scanForDevices()
                timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(Delegate.timerFired(_:)), userInfo: nil, repeats: false)
                CFRunLoopRun()
                sharedManager.stopScanning()
                timer?.invalidate()
                timer = nil
            }
        }

        let delegate = Delegate(name: name, timeout: timeout)

        sharedManager.delegate = delegate
        defer { sharedManager.delegate = nil }
        
        delegate.waitForConnection()
        
        return delegate.sphero
    }

    public class func nearest(timeout: TimeInterval = 5) -> Sphero? {
        class Delegate: SpheroManagerDelegate {
            var sphero: Sphero? = nil

            let timeout: TimeInterval

            init(timeout: TimeInterval) {
                self.timeout = timeout
            }

            var knownSpheros: [UUID: SpheroDescription] = [:]

            func spheroManager(_ spheroManager: SpheroManager, didDiscover spheroDescription: SpheroDescription) {
                knownSpheros[spheroDescription.identifier] = spheroDescription
            }

            func spheroManager(_ spheroManager: SpheroManager, didConnect sphero: Sphero) {
                self.sphero = sphero
                CFRunLoopStop(CFRunLoopGetMain())
            }

            func spheroManager(_ spheroManager: SpheroManager, didFailToConnect spheroDescription: SpheroDescription, error: Error?) {
                self.sphero = nil
                CFRunLoopStop(CFRunLoopGetMain())
            }

            var timer: Timer?

            @objc func timerFired(_ timer: Timer) {
                let spheroDescriptions = knownSpheros.values

                guard let closestSpheroDescription = spheroDescriptions.sorted(by: { $0.rssi > $1.rssi && $0.rssi != 127 /* invalid RSSI */ }).first else {
                    CFRunLoopStop(CFRunLoopGetMain())
                    return
                }

                sharedManager.connectTo(closestSpheroDescription)
            }

            func waitForConnection() {
                sharedManager.scanForDevices()
                timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(Delegate.timerFired(_:)), userInfo: nil, repeats: false)
                CFRunLoopRun()
                sharedManager.stopScanning()
                timer?.invalidate()
                timer = nil
            }
        }

        let delegate = Delegate(timeout: timeout)

        sharedManager.delegate = delegate
        defer { sharedManager.delegate = nil }
        
        delegate.waitForConnection()
        
        return delegate.sphero

    }
}
