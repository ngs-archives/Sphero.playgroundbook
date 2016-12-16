//: ## Control a Sphero device with your iPad!
//:
//: When you hit the "Run My Code" button on this page you will see a joystick-like
//: control that lets you drive a Bluetooth LE-capable Sphero robot around your room.
//: But that's not all, [on the next page](@next) you can write Swift code to drive
//: your Sphero device directly.
//:
//: For more information on programming the Sphero robots, you can see the documentation at
//: [http://sdk.sphero.com/api-reference/api-quick-reference/](http://sdk.sphero.com/api-reference/api-quick-reference/).  The Swift code used in this playground is inspired by the open source
//: Sphero code published by Orbotix at: [https://github.com/orbotix](https://github.com/orbotix).

// A Sphero object which is automatically set to the nearest device.
var sphero: Sphero?

//#-editable-code
let viewController = SpheroViewController()

viewController.joystickMoved = { angle, magnitude in
    let rollForce = UInt8(magnitude * 0.5 * Double(UInt8.max))
    let rollAngle = UInt16(radiansToDegrees(angle))
    
    sphero?.roll(speed: rollForce, heading: rollAngle)    
}

viewController.colorSelected = { color in
    sphero?.setColor(color)
}

import PlaygroundSupport

PlaygroundPage.current.liveView = viewController
//#-end-editable-code

//#-hidden-code
import UIKit
DispatchQueue.main.async {

//#-end-hidden-code
sphero = Sphero.nearest()
//#-hidden-code
    if sphero == nil {
        let alertController = UIAlertController(title: "Unable to find a Sphero device", message: "No Sphero devices were in range.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            PlaygroundPage.current.finishExecution()
        })
        viewController.present(alertController, animated: true, completion: nil)
    }
}
//#-end-hidden-code
