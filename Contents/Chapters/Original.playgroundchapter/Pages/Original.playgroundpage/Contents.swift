//: ## The original prototype.
//:
//: This is the original prototype of the Sphero-controlling playground. It was written entirely on an iPad, using just the
//: [Sphero reference documentation](http://sdk.sphero.com/api-reference/api-quick-reference/) and the CoreBluetooth framework.


import Foundation
import CoreBluetooth
import UIKit

protocol CommandType {
    var answer: Bool { get }
    var resetTimeout: Bool { get }
    var deviceID: UInt8 { get }
    var commandID: UInt8 { get }
    var payload: Data? { get }
}

extension CommandType {
    var answer: Bool {
        return true
    }
    
    var resetTimeout: Bool {
        return true
    }
    
    var sop2: UInt8 {
        var value: UInt8 = 0b11111100
        if answer {
            value |= 1 << 1
        }
        if resetTimeout {
            value |= 1 << 0
        }
        
        return value
    }
    
    func dataForPacket(sequenceNumber: UInt8 = 0) -> Data {
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

protocol CoreCommandType: CommandType {
}

extension CoreCommandType {
    var deviceID: UInt8 {
        return 0x00
    }
}

protocol SpheroCommandType: CommandType {
}

extension SpheroCommandType {
    var deviceID: UInt8 {
        return 0x02
    }
}

struct PingCommand: CoreCommandType {
    let commandID: UInt8 = 0x01
    let payload: Data? = nil
}

struct UpdateHeadingCommand: SpheroCommandType {
    let commandID: UInt8 = 0x01
    
    var heading: UInt16
    init(heading: UInt16) {
        self.heading = heading
    }
    
    var payload: Data? {
        let clampedHeading = (heading % 360)
        let headingLeft = UInt8((clampedHeading >> 8) & 0xff)
        let headingRight = UInt8(clampedHeading & 0xff)
        
        return Data(bytes: [headingLeft, headingRight])
    }
}

struct SetLedColor: SpheroCommandType {
    let commandID:UInt8 = 0x20
    
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var save: Bool
    
    init(red: UInt8, green: UInt8, blue: UInt8, save: Bool = false) {
        self.red = red
        self.green = green
        self.blue = blue
        self.save = save
    }
    
    init(color: UIColor, save: Bool = false) {
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
    
    var payload: Data? {
        let data = Data(bytes: [red, green, blue, save ? 1 : 0])
        return data
    }
}

struct SetBackLEDBrightness: SpheroCommandType {
    let commandID: UInt8 = 0x21
    
    var brightness: UInt8
    
    init(brightness: UInt8) {
        self.brightness = brightness
    }
    
    var payload: Data? {
        let data = Data(bytes: [brightness])
        return data
    }
}

struct RollCommand: SpheroCommandType {
    let commandID: UInt8 = 0x30
    
    var speed: UInt8
    var heading: UInt16
    var state: UInt8
    
    init(speed: UInt8, heading: UInt16, state: UInt8 = 1) {
        self.speed = speed
        self.heading = heading
        self.state = state
    }
    
    var payload: Data? {
        let clampedHeading = (heading % 360)
        let headingLeft = UInt8((clampedHeading >> 8) & 0xff)
        let headingRight = UInt8(clampedHeading & 0xff)
        
        return Data(bytes: [speed, headingLeft, headingRight, state])
    }
}


public class SpheroController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    public var primaryColor: UIColor! {
        didSet {
            let colorCommand = SetLedColor(color: primaryColor)
            sphero.availablePeripheral?.writeValue(colorCommand.dataForPacket() as Data, for: commandsCharacteristic, type: .withResponse)
        }
    }
    
    public var rearLedBrightness: UInt8 = 0 {
        didSet {
            let brightnessCommand = SetBackLEDBrightness(brightness: rearLedBrightness)
            sphero.availablePeripheral?.writeValue(brightnessCommand.dataForPacket(), for: commandsCharacteristic, type: .withResponse)
        }
    }
    
    public func roll(velocity: UInt8, heading: UInt16) {
        let rollCommand = RollCommand(speed: velocity, heading: heading)
        sphero.availablePeripheral?.writeValue(rollCommand.dataForPacket(), for: commandsCharacteristic, type: .withResponse)
    }
    
    public func updateHeading(heading: UInt16) {
        let updateHeading = UpdateHeadingCommand(heading: heading)
        sphero.availablePeripheral?.writeValue(updateHeading.dataForPacket(), for: commandsCharacteristic, type: .withResponse)
    }
    
    private enum Peripheral {
        case none
        case attached(CBPeripheral)
        case available(CBPeripheral)
        
        var availablePeripheral: CBPeripheral? {
            get {
                if case let .available(sphero) = self {
                    return sphero
                } else {
                    return nil
                }
            }
        }
    }
    
    private enum Service {
        static let BLE = CBUUID(string: "22bb746f-2bb0-7554-2d6f-726568705327")
        static let RobotControl = CBUUID(string: "22bb746f-2ba0-7554-2d6f-726568705327")
    }
    
    private enum Characteristic {
        // BLE service
        static let Wake = CBUUID(string: "22bb746f-2bbf-7554-2d6f-726568705327")
        static let TXPower = CBUUID(string: "22bb746f-2bb2-7554-2d6f-726568705327")
        static let AntiDoS = CBUUID(string: "22bb746f-2bbd-7554-2d6f-726568705327")
        
        // RobotControl service
        static let Commands = CBUUID(string: "22bb746f-2ba1-7554-2d6f-726568705327")
        static let Response = CBUUID(string: "22bb746f-2ba6-7554-2d6f-726568705327")
    }
    
    
    lazy var central: CBCentralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    
    public func connectToSpheroIfAvailable() {
        _ = central
    }
    
    private var sphero: Peripheral = .none
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [Service.RobotControl], options: nil)
        case .poweredOff:
            central.stopScan()
        case .resetting:
            break
        case .unauthorized:
            break
        case .unknown:
            break
        case .unsupported:
           break
        }
    }
    
    var peripherals: [CBPeripheral: Int] = [:]
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : AnyObject], rssi RSSI: NSNumber) {
        peripherals[peripheral] = RSSI.intValue
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5)) {
            if case .none = self.sphero {
                let peripheral: CBPeripheral
                let sortedKeys = Array(self.peripherals.keys).sorted { left, right in
                    return self.peripherals[left]! > self.peripherals[right]!
                }
                peripheral = sortedKeys.first!
                self.sphero = .attached(peripheral)
                central.connect(peripheral, options: nil)
                central.stopScan()
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Service.BLE, Service.RobotControl])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        peripheral.delegate = nil
        sphero = .none
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: NSError?) {
        print("Failed: \(error)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        guard let services = peripheral.services else {
            return
        }
        
        services.forEach { service in
            switch service.uuid {
            case let uuid where uuid == Service.BLE:
                peripheral.discoverCharacteristics([Characteristic.Wake, Characteristic.TXPower, Characteristic.AntiDoS], for: service)
            case let uuid where uuid == Service.RobotControl:
                peripheral.discoverCharacteristics([Characteristic.Commands, Characteristic.Response], for: service)
            default:
                fatalError("We should only find either the BLE or RobotControl service!")
            }
        }
    }
    
    var wakeCharacteristic: CBCharacteristic!
    var txPowerCharacteristic: CBCharacteristic!
    var antiDoSCharacteristic: CBCharacteristic!
    var commandsCharacteristic: CBCharacteristic!
    var responseCharacteristic: CBCharacteristic!
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: NSError?) {
        guard let characteristics = service.characteristics else {
            return
        }
        
        characteristics.forEach { characteristic in
            switch characteristic.uuid {
            case let uuid where uuid == Characteristic.Wake:
                wakeCharacteristic = characteristic
            case let uuid where uuid == Characteristic.TXPower:
                txPowerCharacteristic = characteristic
            case let uuid where uuid == Characteristic.AntiDoS:
                antiDoSCharacteristic = characteristic
            case let uuid where uuid == Characteristic.Commands:
                commandsCharacteristic = characteristic
            case let uuid where uuid == Characteristic.Response:
                responseCharacteristic = characteristic
            default:
                fatalError("Unknown characteristic")
            }
            
            if wakeCharacteristic != nil &&
                txPowerCharacteristic != nil &&
                antiDoSCharacteristic != nil &&
                commandsCharacteristic != nil &&
                responseCharacteristic != nil {
                peripheral.writeValue("011i3".data(using: String.Encoding.ascii)!, for: antiDoSCharacteristic, type: .withResponse)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: NSError?) {
        if characteristic === responseCharacteristic {
            sphero = .available(peripheral)
            rearLedBrightness = 128            
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: NSError?) {
        if characteristic === antiDoSCharacteristic {
            peripheral.writeValue(Data(bytes: [7]), for: txPowerCharacteristic, type: .withResponse)
        }
        else if characteristic === txPowerCharacteristic {
            peripheral.writeValue(Data(bytes: [1]), for: wakeCharacteristic, type: .withResponse)
        }
        else if characteristic === wakeCharacteristic {
            peripheral.setNotifyValue(true, for: responseCharacteristic)
        }
        else if characteristic === commandsCharacteristic {
        }
    }
    
    public func disconnect() {
        if let sphero = sphero.availablePeripheral {
            central.cancelPeripheralConnection(sphero)
        }
    }
}

class ColorWell: UIView {
    let color: UIColor
    var selected = false {
        didSet {
            if selected {
                self.layer.borderWidth = 2
            } else {
                self.layer.borderWidth = 0
            }
        }
    }
    let action: (ColorWell) -> Void
    
    init(color: UIColor, action: @escaping (ColorWell) -> Void) {
        self.color = color
        self.action = action
        
        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        
        self.layer.borderColor = UIColor.black.cgColor
        self.layer.cornerRadius = 30.0
        self.backgroundColor = color
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(ColorWell.tapped(_:)))
        self.addGestureRecognizer(tapRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 60, height: 60)
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        action(self)
    }
}

private let pi = CGFloat(M_PI)
private let tau = CGFloat(2 * M_PI)

/*: 
 ![Triangle](triangle.png)
 ![Law of Cosines](formula.png)
 For more information on the law of cosines see the [wikipedia article](https://en.wikipedia.org/wiki/Law_of_cosines)
*/

func internalAngle(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> CGFloat{
    let a = distanceBetweenPoints(firstPoint: pointC, secondPoint: pointB)
    let b = distanceBetweenPoints(firstPoint: pointA, secondPoint: pointC)
    let c = distanceBetweenPoints(firstPoint: pointA, secondPoint: pointB)
    
    let numerator = pow(a, 2) + pow(b, 2) - pow(c, 2)
    let denominator = 2 * a * b
    
    let theta = acos(numerator/denominator)
    
    return theta
}

func distanceBetweenPoints(firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
    let horizontalDistance = firstPoint.x - secondPoint.x
    let verticalDistance = firstPoint.y - secondPoint.y
    
    let totalDistance = sqrt(pow(horizontalDistance, 2) + pow(verticalDistance, 2))
    
    return abs(totalDistance)
}

public class ViewController: UIViewController {
    var square: UIView!
    var pointView: UIView!
    
    public var joystickActionBlock: ((Double, Double) -> Void)?
    public var colorSelectedBlock: ((UIColor) -> Void)?
    
    var point: CGPoint? {
        didSet {
            if let point = point {
                UIView.performWithoutAnimation{
                    pointView.center = point
                }
            } else {
                let midpoint = CGPoint(x: square.frame.midX, y: square.frame.midY)
                pointView.center = midpoint
            }
        }
    }
    
    var selectedWell: ColorWell! {
        didSet {
            selectedWell.selected = true
            if let old = oldValue {
                old.selected = false
            }
            
            colorSelectedBlock?(selectedWell.color)
        }
    }
    
    var controls: UIStackView!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        square = UIView()
        view.addSubview(square)
        square.translatesAutoresizingMaskIntoConstraints = false
        square.backgroundColor = UIColor.lightGray
        square.layer.cornerRadius = 10
        square.widthAnchor.constraint(equalToConstant: 200).isActive = true
        square.heightAnchor.constraint(equalToConstant: 200).isActive = true
        square.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        square.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        pointView = UIView()
        view.addSubview(pointView)
        pointView.backgroundColor = UIColor.black
        pointView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        pointView.center = view.center
        pointView.layer.cornerRadius = 10
        
        controls = UIStackView(arrangedSubviews: [])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.distribution = .equalCentering
        
        let colors = [#colorLiteral(red: 0.2818343937, green: 0.5693024397, blue: 0.1281824261, alpha: 1), #colorLiteral(red: 0.9346159697, green: 0.6284804344, blue: 0.1077284366, alpha: 1), #colorLiteral(red: 0.8949507475, green: 0.1438436359, blue: 0.08480125666, alpha: 1), #colorLiteral(red: 0.7540004253, green: 0, blue: 0.2649998069, alpha: 1), #colorLiteral(red: 0.2856909931, green: 0, blue: 0.9589199424, alpha: 1), #colorLiteral(red: 0.1991284192, green: 0.6028449535, blue: 0.9592232704, alpha: 1)]
        for color in colors {
            let well = ColorWell(color: color, action: { (selectedWell) in
                self.selectedWell = selectedWell
            })
            well.translatesAutoresizingMaskIntoConstraints = false
            
            controls.addArrangedSubview(well)
        }
        
        controls.backgroundColor = UIColor.red
        view.addSubview(controls)
        controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        view.trailingAnchor.constraint(equalTo: controls.trailingAnchor, constant: 20).isActive = true
        view.bottomAnchor.constraint(equalTo: controls.bottomAnchor, constant: 20).isActive = true
        controls.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        point = nil
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchPoint = touches.first?.location(in: view), square.frame.contains(touchPoint) else {
            return
        }
        
        point = touchPoint
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchPoint = touches.first?.location(in: view) else {
            return
        }
        
        //point = touchPoint
        let radiansFromTop = angleForTouchPoint(touchPoint)
        let maxRadius = (square.frame.width - pointView.frame.width) / 2.0
        let distanceFromCenter = distanceBetweenPoints(firstPoint: CGPoint(x: square.frame.midX, y: square.frame.midY), secondPoint: touchPoint)
        
        let radius = min(maxRadius, distanceFromCenter)
        let deltaX = (sin(radiansFromTop) * radius) + square.bounds.midX
        let deltaY = -(cos(radiansFromTop) * radius) + square.bounds.midY
        
        let magnitude = radius / (square.bounds.width / 2)
        joystickActionBlock?(Double(radiansFromTop), Double(magnitude))
        
        point = CGPoint(x: deltaX + square.frame.origin.x, y: deltaY + square.frame.origin.y)
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystickActionBlock?(0, 0)
        point = nil
    }
    
    func angleForTouchPoint(_ touchPoint: CGPoint) -> CGFloat {
        let centerPoint = CGPoint(x: square.frame.midX, y: square.frame.midY)
        
        let pointB: CGPoint
        if touchPoint.x >= square.frame.midX {
            // line segment `a` points "up" if we're on the right half of the cirlce
            // (see the comment above `internalAngle(pointA:, pointB: , pointC:)` for what "line segment `a`" means
            pointB = CGPoint(x: square.frame.midX, y: square.frame.minY)
        } else {
            // otherwise we're on the left and line segment `a` points "down"
            pointB = CGPoint(x: square.frame.midX, y: square.frame.maxY)
        }
        
        var theta = internalAngle(pointA: touchPoint, pointB: pointB, pointC: centerPoint)
        
        if touchPoint.x < square.frame.midX {
            // if `a` points down, we need to add radians from the right half of the circle
            theta += pi
        }
        
        return theta
    }
}

let spheroController = SpheroController()
spheroController.connectToSpheroIfAvailable()

import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

func radiansToDegrees (_ value: Double) -> Double {
    return value * 180.0 / M_PI
}

let vc = ViewController()
vc.view.backgroundColor = UIColor.white
vc.joystickActionBlock = { angle, magnitude in
    let rollForce = UInt8(magnitude * 0.5 * Double(UInt8.max))
    let rollAngle = UInt16(radiansToDegrees(angle))
    
    spheroController.roll(velocity: rollForce, heading: rollAngle)    
}
vc.colorSelectedBlock = { color in
    spheroController.primaryColor = color
}

import PlaygroundSupport
PlaygroundPage.current.liveView = vc

atexit {
    spheroController.disconnect()
    return ()
}
