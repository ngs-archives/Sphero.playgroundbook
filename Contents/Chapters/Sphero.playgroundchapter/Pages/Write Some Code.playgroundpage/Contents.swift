//: Now you can write your own commands to make your Sphero device do whatever you want.
//:
//: Use commands like `roll(speed:heading:)` and `setColor(_:)` to tell your Sphero device what to do.
//#-hidden-code
//
//  Contents.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//
//#-end-hidden-code
//#-editable-code Tap to enter code
import UIKit
import PlaygroundSupport

guard let sphero = Sphero.nearest() else {
	print("Unable to find a Sphero device")
	PlaygroundPage.current.finishExecution()
}

sphero.setColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1))
//#-end-editable-code