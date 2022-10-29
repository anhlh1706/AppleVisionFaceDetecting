//
//  CounterView.swift
//  AppleVisionFaceDetecting
//
//  Created by Lê Hoàng Anh on 29/10/2022.
//

import UIKit

@IBDesignable
final class CounterView: UIView {
    enum DetectFace: Int, CaseIterable {
        case front = 1
        case upToLeft
        case upToRight
        case downToLeft
        case downToRight
        case up
        case down
        case left
        case right
        
        var trackLogName: String {
            switch self {
            case .front:
                return ""
            case .upToLeft:
                return "top_left"
            case .upToRight:
                return "top_right"
            case .downToLeft:
                return "bottom_left"
            case .downToRight:
                return "bottom_right"
            case .up:
                return "top"
            case .down:
                return "bottom"
            case .left:
                return "left"
            case .right:
                return "right"
            }
        }
    }
    
    let markerWidth: CGFloat = 2.0
    let markerSize: CGFloat = 15
    var layers: [CAShapeLayer] = []
    var secondLayers: [CAShapeLayer] = []
    var circle: CAShapeLayer?
    
    private let numberOfGlasses = 80
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    func startScanning() {
        let endAngle: CGFloat = .pi * 2
        let arcLengthPerGlass = endAngle / CGFloat(numberOfGlasses)
        let radius = max(bounds.width, bounds.height) / 2 - markerSize
        layer.backgroundColor = UIColor.clear.cgColor
        for index in 1...numberOfGlasses {
            DispatchQueue.main.asyncAfter(deadline: .now()) { [self] in
                
                let firstLayer = firstLayer(rect: bounds, index: index, radius: radius, arcLengthPerGlass: arcLengthPerGlass)
                let secondLayer = secondLayer(rect: bounds, index: index, radius: radius, arcLengthPerGlass: arcLengthPerGlass)
                
                layers.append(firstLayer)
                secondLayers.append(secondLayer)
                
                layer.addSublayer(secondLayer)
                layer.addSublayer(firstLayer)
                
                secondLayer.zPosition = 2000
                
                let animation = CABasicAnimation(keyPath: "strokeEnd")
                animation.fromValue = 0
                animation.duration = 0.25
                firstLayer.add(animation, forKey: "anim")
                secondLayer.add(animation, forKey: "anim2")
            }
        }
    }
    
    fileprivate func animation(firstLayer: CAShapeLayer, secondLayer: CAShapeLayer, index: Int) {
        firstLayer.opacity = 0
        secondLayer.strokeColor = UIColor.green.cgColor
        var target = 0.7
        if index < 10 {
            target += Double(index) * 0.04
        } else {
            target += Double(19 - index) * 0.04
        }
        let animation = CAKeyframeAnimation()
        animation.keyPath = "strokeEnd"
        animation.values = [0.5, target, 0.7]
        animation.duration = 0.8
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        secondLayer.add(animation, forKey: nil)
    }
    
    fileprivate func firstLayer(rect: CGRect, index: Int, radius: CGFloat, arcLengthPerGlass: CGFloat) -> CAShapeLayer {
        let markerPath = UIBezierPath()
        let angle = arcLengthPerGlass * CGFloat(index) - .pi / 2
        let caLayer = CAShapeLayer()
        caLayer.strokeColor = UIColor.gray.cgColor
        
        let circleX1 = (radius - 2 * markerSize) * cos(CGFloat(angle))
        let circleY1 = (radius - 2 * markerSize) * sin(CGFloat(angle))
        
        let circleX2 = (radius - markerSize) * cos(CGFloat(angle))
        let circleY2 = (radius - markerSize) * sin(CGFloat(angle))
        
        markerPath.move(to: CGPoint(x:circleX1 + rect.midX, y: circleY1 + rect.midY))
        markerPath.addLine(to: CGPoint(x:circleX2 + rect.midX, y: circleY2 + rect.midY))
        
        caLayer.path = markerPath.cgPath
        caLayer.lineWidth = 3
        caLayer.lineCap = .round
        
        return caLayer
    }
    
    fileprivate func secondLayer(rect: CGRect, index: Int, radius: CGFloat, arcLengthPerGlass: CGFloat) -> CAShapeLayer {
        let markerPath = UIBezierPath()
        let angle = arcLengthPerGlass * CGFloat(index) - .pi / 2
        let caLayer = CAShapeLayer()
        caLayer.strokeColor = UIColor.clear.cgColor
        
        let circleX1 = (radius - 2 * markerSize) * cos(CGFloat(angle))
        let circleY1 = (radius - 2 * markerSize) * sin(CGFloat(angle))
        
        let circleX2 = (radius) * cos(CGFloat(angle))
        let circleY2 = (radius) * sin(CGFloat(angle))
        
        markerPath.move(to: CGPoint(x:circleX1 + rect.midX, y: circleY1 + rect.midY))
        markerPath.addLine(to: CGPoint(x:circleX2 + rect.midX, y: circleY2 + rect.midY))
        
        caLayer.path = markerPath.cgPath
        caLayer.lineWidth = 3
        caLayer.lineCap = .round
        
        return caLayer
    }
    
    func runAnimation(detect: DetectFace) {
        guard let detectLayer = getLayer(detect: detect) else { return }
        if detectLayer.first.isEmpty || detectLayer.sencond.isEmpty {
            return
        }
        DispatchQueue.main.async {
            for i in 0..<detectLayer.first.count {
                self.animation(firstLayer: detectLayer.first[i], secondLayer: detectLayer.sencond[i], index: i)
            }
        }
    }
    
    func removeAllActiveFaces() {
        DispatchQueue.main.async { [self] in
            layers.forEach({ $0.removeFromSuperlayer() })
            secondLayers.forEach({ $0.removeFromSuperlayer() })
            layers = []
            secondLayers = []
        }
    }
    
    func getLayer(detect: DetectFace) -> (first: [CAShapeLayer], sencond: [CAShapeLayer])? {
        guard layers.count > 75 && secondLayers.count > 75 else { return nil }
        if detect == .up {
            return (Array(layers[75..<80] + layers[...5]), Array(secondLayers[75..<80] + secondLayers[...5]))
        }
    
        if detect == .upToRight {
            return (Array(layers[5..<15]), Array(secondLayers[5..<15]))
        }
        
        if detect == .right{
           return (Array(layers[15..<25]), Array(secondLayers[15..<25]))
        }
        
        if detect == .downToRight {
            return (Array(layers[25..<35]), Array(secondLayers[25..<35]))
        }
        
        if detect == .down {
            return (Array(layers[35..<45]), Array(secondLayers[35..<45]))
        }
        
        if detect == .downToLeft {
            return (Array(layers[45..<55]), Array(secondLayers[45..<55]))
        }
        
        if detect == .left {
            return (Array(layers[55..<65]), Array(secondLayers[55..<65]))
          
        }

        if detect == .upToLeft {
            return (Array(layers[65..<75]), Array(secondLayers[65..<75]))
        }
        
        return ([], [])
    }
}
