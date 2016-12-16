//
//  ViewController.swift
//  Sphero.playgroundbook
//
//  Copyright © 2016 Apple Inc. All rights reserved.
//

import UIKit

private class ColorWell: UIView {
    let color: UIColor
    var selected = false {
        didSet {
            if selected {
                self.layer.borderWidth = 3
            } else {
                self.layer.borderWidth = 1
            }
        }
    }
    let action: (ColorWell) -> Void
    
    init(color: UIColor, action: @escaping (ColorWell) -> Void) {
        self.color = color
        self.action = action
        
        super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        
        self.layer.borderColor = UIColor.white.cgColor
		self.layer.borderWidth = 1
        self.layer.cornerRadius = 20.0
        self.backgroundColor = color
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(ColorWell.tapped(_:)))
        self.addGestureRecognizer(tapRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 40, height: 40)
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        action(self)
    }
}

private let pi = CGFloat(M_PI)
private let tau = CGFloat(2 * M_PI)

private func internalAngle(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> CGFloat {
    let a = distanceBetweenPoints(firstPoint: pointC, secondPoint: pointB)
    let b = distanceBetweenPoints(firstPoint: pointA, secondPoint: pointC)
    let c = distanceBetweenPoints(firstPoint: pointA, secondPoint: pointB)
    
    let numerator = pow(a, 2) + pow(b, 2) - pow(c, 2)
    let denominator = 2 * a * b
    
    let theta = acos(numerator/denominator)
    
    return theta
}

private func distanceBetweenPoints(firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
    let horizontalDistance = firstPoint.x - secondPoint.x
    let verticalDistance = firstPoint.y - secondPoint.y
    
    let totalDistance = sqrt(pow(horizontalDistance, 2) + pow(verticalDistance, 2))
    
    return abs(totalDistance)
}

public class SpheroViewController: UIViewController {
    private var circle: UIImageView!
    private var pointView: UIView!
    
    public var joystickMoved: ((_ angle: Double, _ magnitude: Double) -> Void)?
    public var colorSelected: ((UIColor) -> Void)?
    
    private var point: CGPoint? {
    	didSet {
	        if let point = point {
	            UIView.performWithoutAnimation {
	                pointView.center = point
	            }
	        } else {
	            let midpoint = CGPoint(x: view.frame.midX, y: view.frame.midY)
	            pointView.center = midpoint
	        }
    	}
    }
    
    private var selectedWell: ColorWell! {
        didSet {
            selectedWell.selected = true
            if let old = oldValue {
                old.selected = false
            }
            
            colorSelected?(selectedWell.color)
        }
    }
    
    private var controls: UIStackView!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
		
		view.backgroundColor = UIColor.clear
        
        circle = UIImageView(image: UIImage(named: "Boundary")!)
        view.addSubview(circle)
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        circle.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        pointView = UIImageView(image: UIImage(named: "Notches")!)
		pointView.contentMode = .scaleAspectFit
        view.addSubview(pointView)
        pointView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        pointView.frame = CGRect(x: 0, y: 0, width: 65, height: 65)
        pointView.center = view.center
        pointView.layer.cornerRadius = 32
        
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
        view.bottomAnchor.constraint(equalTo: controls.bottomAnchor, constant: 100).isActive = true
        controls.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        point = nil
    }
    
    private var touchedInside = false
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchPoint = touches.first?.location(in: view), circle.frame.contains(touchPoint) else {
            return
        }
        
        touchedInside = true
        point = touchPoint
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchedInside else {
            return
        }
        
        guard let touchPoint = touches.first?.location(in: view) else {
            return
        }
        
        let radiansFromTop = angleForTouchPoint(touchPoint)
        let maxRadius = (circle.frame.width - pointView.frame.width) / 2.0
        let distanceFromCenter = distanceBetweenPoints(firstPoint: CGPoint(x: circle.frame.midX, y: circle.frame.midY), secondPoint: touchPoint)
        
        let radius = min(maxRadius, distanceFromCenter)
        let deltaX = (sin(radiansFromTop) * radius) + circle.bounds.midX
        let deltaY = -(cos(radiansFromTop) * radius) + circle.bounds.midY
        
        let magnitude = radius / (circle.bounds.width / 2)
        joystickMoved?(Double(radiansFromTop), Double(magnitude))
        
        point = CGPoint(x: deltaX + circle.frame.origin.x, y: deltaY + circle.frame.origin.y)
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        joystickMoved?(0, 0)
        point = nil
        touchedInside = false
    }
    
    private func angleForTouchPoint(_ touchPoint: CGPoint) -> CGFloat {
        let centerPoint = CGPoint(x: circle.frame.midX, y: circle.frame.midY)
        
        let pointB: CGPoint
        if touchPoint.x >= circle.frame.midX {
            // line segment `a` points "up" if we're on the right half of the cirlce
            // (see the comment above `internalAngle(pointA:, pointB: , pointC:)` for what "line segment `a`" means
            pointB = CGPoint(x: circle.frame.midX, y: circle.frame.minY)
        } else {
            // otherwise we're on the left and line segment `a` points "down"
            pointB = CGPoint(x: circle.frame.midX, y: circle.frame.maxY)
        }
        
        var theta = internalAngle(pointA: touchPoint, pointB: pointB, pointC: centerPoint)
        
        if touchPoint.x < circle.frame.midX {
            // if `a` points down, we need to add radians from the right half of the circle
            theta += pi
        }
        
        return theta
    }
	
    override public func viewWillLayoutSubviews() {
        point = nil
    }
}
