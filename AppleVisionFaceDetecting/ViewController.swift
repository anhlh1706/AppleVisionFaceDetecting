//
//  ViewController.swift
//  AppleVisionFaceDetecting
//
//  Created by Lê Hoàng Anh on 29/10/2022.
//

import UIKit
import Vision
import Anchorage
import AVFoundation
import Combine

final class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let captureSession = AVCaptureSession()
    
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var counterView: CounterView!
    
    private var innerCircleLayer: CAShapeLayer?
    
    private var overlayView: UIView!
    
    private var verticalGradientView: UIView!
    private var horizontalGradientView: UIView!
    
    private var detects: [CounterView.DetectFace] = [] {
        didSet { runWaitting() }
    }
    
    private let defaultVerticalTransformation: CGFloat = -.pi / 2.2
    private let defaultHorizontalTransformation: CGFloat = .pi / 2.2
    
    private let gradientLayer = CAGradientLayer()
    private let gradientLayer2 = CAGradientLayer()
    
    private var cancellables = [AnyCancellable]()
    
    /// Waiting time between detections
    var isWaitting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupView()
        addCameraInput()
        showCameraFeed()
        getCameraFrames()
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        counterView.startScanning()
        drawCircle()
    }
    
    func setupView() {
        counterView = CounterView()
        view.addSubview(counterView)
        counterView.centerXAnchor == view.centerXAnchor
        counterView.centerYAnchor == view.centerYAnchor - 80

        counterView.widthAnchor == view.widthAnchor
        counterView.heightAnchor == view.widthAnchor
        
        overlayView = UIView()
        counterView.addSubview(overlayView)
        overlayView.edgeAnchors == counterView.edgeAnchors + 55
        
        verticalGradientView = UIView()
        counterView.addSubview(verticalGradientView)
        verticalGradientView.edgeAnchors == counterView.edgeAnchors + 70
        
        horizontalGradientView = UIView()
        counterView.addSubview(horizontalGradientView)
        horizontalGradientView.edgeAnchors == counterView.edgeAnchors + 70
        
        // MARK: - Setup View's Properties
        counterView.layer.zPosition = 3000
    }
    
    func setupGradient() {
        gradientLayer.removeFromSuperlayer()
        gradientLayer.colors = [UIColor.blue.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
        gradientLayer.locations = [0.0 , 0.35]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.frame = verticalGradientView.bounds
        gradientLayer.cornerRadius = verticalGradientView.bounds.height / 2
        verticalGradientView.layer.insertSublayer(gradientLayer, at: 0)
        verticalGradientView.transform3D = CATransform3DMakeRotation(defaultVerticalTransformation, 1, 0, 0)
        
        gradientLayer2.removeFromSuperlayer()
        gradientLayer2.colors = [UIColor.green.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
        gradientLayer2.locations = [0.0 , 0.35]
        gradientLayer2.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer2.endPoint = CGPoint(x: 1, y: 0)
        gradientLayer2.frame = horizontalGradientView.bounds
        gradientLayer.cornerRadius = horizontalGradientView.bounds.height / 2
        horizontalGradientView.layer.insertSublayer(gradientLayer2, at: 0)
        horizontalGradientView.transform3D = CATransform3DMakeRotation(defaultHorizontalTransformation, 0, 1, 0)
        
        verticalGradientView
            .publisher(for: \.frame)
            .map({ $0.height / 2 })
            .assign(to: \.cornerRadius, on: verticalGradientView.layer)
            .store(in: &cancellables)
        
        horizontalGradientView
            .publisher(for: \.frame)
            .map({ $0.height / 2 })
            .assign(to: \.cornerRadius, on: horizontalGradientView.layer)
            .store(in: &cancellables)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async { [self] in
            previewLayer.frame = overlayView.bounds
            previewLayer.cornerRadius = overlayView.bounds.height / 2
            setupGradient()
        }
        
    }
    
    func runWaitting() {
        isWaitting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isWaitting = false
        }
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .front).devices.first else {
            present(UIAlertController(title: "Error", message: "No camera detected", preferredStyle: .actionSheet), animated: true)
            return
        }
        
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        captureSession.addInput(cameraInput)
    }
    
    
    private func showCameraFeed() {
        previewLayer.videoGravity = .resizeAspectFill
        overlayView.layer.addSublayer(previewLayer)
        previewLayer.frame = overlayView.bounds
    }
    
    
    private func getCameraFrames() {
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        captureSession.addOutput(videoDataOutput)
        
        guard let connection = videoDataOutput.connection(with: AVMediaType.video), connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to get image from sample buffer")
            return
        }
        detectFace(in: frame)
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation], let face = results.first {
                    let rotX = (face.pitch ?? 0) as! CGFloat
                    let rotY = (face.yaw ?? 0) as! CGFloat
                    self.checkStep(rotX: rotX, rotY: rotY)
                }
            }
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    func radiansToDegress(radians: Double) -> Double {
        return radians * 180 / (.pi)
    }
    
    func drawCircle() {
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: overlayView.bounds.midX, y: overlayView.bounds.midY),
            radius: overlayView.frame.size.height / 2,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true)
        
        let shapeLayer = CAShapeLayer()
        innerCircleLayer = shapeLayer
        shapeLayer.path = circlePath.cgPath
        
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 2
        
        overlayView.layer.addSublayer(shapeLayer)
    }
}

// MARK: - Detect face rotation
private extension ViewController {
    
    /// Kiểm tra và add góc mặt mới nếu có
    func checkStep(rotX: CGFloat, rotY: CGFloat) {
        if isWaitting { return }
        let rotX = -radiansToDegress(radians: rotX)
        let rotY = radiansToDegress(radians: rotY)
        if checkIfFaceCenter(rotX: rotX, rotY: rotY) && !detects.contains(.front) {
            detects.append(.front)
            return
        }
        
        if checkHeadRight(rotX: rotX, rotY: rotY) || checkHeadLeft(rotX: rotX, rotY: rotY) {
            return
        }
        
        if rotX > 12 && !detects.contains(.up) {
            detects.append(.up)
            counterView.runAnimation(detect: .up)
            return
        }
        
        if (rotX < -12) && !detects.contains(.down) {
            detects.append(.down)
            counterView.runAnimation(detect: .down)
            return
        }
        
        if detects.count == CounterView.DetectFace.allCases.count {
            detects = []
            counterView.removeAllActiveFaces()
            counterView.startScanning()
        }
    }
    
    func checkIfFaceCenter(rotX: CGFloat, rotY: CGFloat) -> Bool {
        if rotX >= -10 && rotX <= 10 && rotY >= -10 && rotY <= 10 {
            return true
        }
        return false
    }
    
    func checkHeadRight(rotX: CGFloat, rotY: CGFloat) -> Bool {
        if rotY < 10 {
            return false
        }
        
        if rotX > 17 && !detects.contains(.upToRight) {
            detects.append(.upToRight)
            counterView.runAnimation(detect: .upToRight)
            return true
        }
        
        if rotX < 5 && !detects.contains(.downToRight) {
            detects.append(.downToRight)
            counterView.runAnimation(detect: .downToRight)
            return true
        }
        
        if !detects.contains(.right) {
            detects.append(.right)
            counterView.runAnimation(detect: .right)
            return true
        }
        return false
    }
    
    func checkHeadLeft(rotX: CGFloat, rotY: CGFloat) -> Bool {
        if rotY > -10 {
            return false
        }
        
        if rotX > 12, !detects.contains(.upToLeft) {
            detects.append(.upToLeft)
            counterView.runAnimation(detect: .upToLeft)
            return true
        }
        
        if rotX < 5, !detects.contains(.downToLeft) {
            detects.append(.downToLeft)
            counterView.runAnimation(detect: .downToLeft)
            return true
        }
        
        if !detects.contains(.left) {
            detects.append(.left)
            counterView.runAnimation(detect: .left)
            return true
        }
        return false
    }
}
