//: [On the previous page](@previous), you used a joystick to control a Sphero
//: robot by hand.
//:
//: This page uses Swift code to control the robot, moving your Sphero in a square,
//: forever. The Sphero robot rolls in each direction for a second, then turns 90º.
//: Once you've gotten the hang of squares, [continue to the next page](@next)
//: where you can tell your Sphero robot to do whatever you want.

//#-editable-code Tap to enter code
import UIKit
import PlaygroundSupport

guard let sphero = Sphero.nearest() else {
	print("Unable to find a Sphero device")
	PlaygroundPage.current.finishExecution()
}

let colors = [#colorLiteral(red: 0.1991284192, green: 0.6028449535, blue: 0.9592232704, alpha: 1), #colorLiteral(red: 0.1603052318, green: 0, blue: 0.8195188642, alpha: 1), #colorLiteral(red: 0.7540004253, green: 0, blue: 0.2649998069, alpha: 1), #colorLiteral(red: 0.9101451635, green: 0.2575159371, blue: 0.1483209133, alpha: 1), #colorLiteral(red: 0.9446166754, green: 0.6509571671, blue: 0.1558967829, alpha: 1), #colorLiteral(red: 0.4028071761, green: 0.7315050364, blue: 0.2071235478, alpha: 1)]

var i = 0
func rest() {
	sleep(1)
    let color = colors[i % colors.count]
    sphero.setColor(color)
    
    i += 1
}

while true {
	sphero.roll(speed: UInt8.max / 4, heading: 0)
	rest()
	sphero.roll(speed: UInt8.max / 4, heading: 90)
	rest()
	sphero.roll(speed: UInt8.max / 4, heading: 180)
	rest()
	sphero.roll(speed: UInt8.max / 4, heading: 270)
	rest()
}
//#-end-editable-code
