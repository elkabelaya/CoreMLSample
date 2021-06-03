//
//  VisionDetectionView.swift
//  CoreMLApp
//
//  Created by exey on 22.03.2021.
//

import UIKit
import SwiftUI
import Vision
import CoreML

public struct VisionDetectionView: UIViewRepresentable {
    
    @ObservedObject var viewModel: VisionDetectionViewModel = .init()
    
    public init() {}
    
    public func makeUIView(context: UIViewRepresentableContext<VisionDetectionView>) -> UIView {
        viewModel.makeDetection()
        return viewModel.resultView
    }
    
    public func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<VisionDetectionView>) {
        
    }
    
}


final class VisionDetectionViewModel: ObservableObject {
    
    // Trained Models
    private let segmentationModel: DeepLabV3Int8LUT = .init()
    private var segmentationRequest: VNCoreMLRequest?
    private var segmentationVisionModel: VNCoreMLModel?
    
    private let objectModel = YOLOv3Int8LUT()
    private var objectRequest: VNCoreMLRequest?
    private var objectVisionModel: VNCoreMLModel?
    
    // UI
    private var detectionLayer: CALayer?
    private var currentImageView: UIImageView
    private var detectionView: UIView
    private var drawingView: DrawingSegmentationView
    
    var resultView: UIView
    
    
    init(/*image:Image*/) {
        //let uiImage = 
        resultView = UIView(frame: CGRect(x: 0, y: 0, width: 768, height: 768))
        
        // Basic UI
        currentImageView = UIImageView(image: UIImage(named: "sk8er"))
        currentImageView.frame = CGRect(x: 0, y: 0, width: 768, height: 768)
        resultView.addSubview(currentImageView)
        drawingView = DrawingSegmentationView(frame: currentImageView.frame ?? .zero)
        drawingView.isUserInteractionEnabled = false
        drawingView.alpha = 0.5
        resultView.addSubview(drawingView)
        detectionView = UIView(frame: currentImageView.frame ?? .zero)
        detectionView.isUserInteractionEnabled = false
        detectionView.alpha = 0.75
        resultView.addSubview(detectionView)
        setupModel()
    }
    
    func makeDetection() {
        addDetectionLayer()
        start()
    }
    
    func addDetectionLayer() {
        detectionLayer = CALayer()
        detectionLayer?.bounds = CGRect(x: 0,y: 0, width: detectionView.bounds.width, height: detectionView.bounds.height)
        detectionLayer?.setAffineTransform(CGAffineTransform(rotationAngle: 0).scaledBy(x: 1, y: -1))
        detectionLayer?.position = CGPoint(x: detectionView.bounds.midX, y: detectionView.bounds.midY)
        detectionView.layer.addSublayer(detectionLayer!)
    }
    
    func start() {
        var image = CIImage(image: self.currentImageView.image!)!
        image = image.transformed(by: CGAffineTransform(scaleX: 513/image.extent.width, y: 513/image.extent.height))
        let context = CIContext(options: nil)
        if let cgimage = context.createCGImage(image, from: image.extent) {
            self.predict(with: cgimage)
        }
    }

    func setupModel() {
        if let segmentationVisionModel = try? VNCoreMLModel(for: segmentationModel.model) {
            self.segmentationVisionModel = segmentationVisionModel
            segmentationRequest = VNCoreMLRequest(model: segmentationVisionModel, completionHandler: visionRequestDidComplete)
            segmentationRequest?.imageCropAndScaleOption = .centerCrop
        }
    
        if let objectVisionModel = try? VNCoreMLModel(for: objectModel.model) {
            self.objectVisionModel = objectVisionModel
            objectRequest = VNCoreMLRequest(model: objectVisionModel, completionHandler: vision2RequestDidComplete)
        }
    }
    
    
    // prediction
    func predict(with image: CGImage) {
        guard let request = segmentationRequest else { fatalError() }
        guard let request2 = objectRequest else { fatalError() }
        
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        try? handler.perform([request2])
    }
    
    // post-processing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let segmentationmap = observations.first?.featureValue.multiArrayValue {
            
            drawingView.segmentationmap = SegmentationResultMLMultiArray(mlMultiArray: segmentationmap)
        }
    }
    
    func vision2RequestDidComplete(request: VNRequest, error: Error?) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionLayer?.sublayers = nil
        if let observations = request.results as? [VNRecognizedObjectObservation]{
            let imageSize = self.detectionView.bounds.size
            for observation in observations {
                // Select only the label with the highest confidence.
                let topLabelObservation = observation.labels[0]
                let objectBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
                
                let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
                
                let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                                identifier: topLabelObservation.identifier,
                                                                confidence: topLabelObservation.confidence)
                shapeLayer.addSublayer(textLayer)
                detectionLayer?.addSublayer(shapeLayer)
                print(topLabelObservation)
            }
        }
        CATransaction.commit()
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.width-20, height: bounds.size.height-20)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: -1))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.borderWidth = 5
        shapeLayer.borderColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    
}

class SegmentationResultMLMultiArray {
    let mlMultiArray: MLMultiArray
    let segmentationmapWidthSize: Int
    let segmentationmapHeightSize: Int
    
    init(mlMultiArray: MLMultiArray) {
        self.mlMultiArray = mlMultiArray
        self.segmentationmapWidthSize = mlMultiArray.shape[0].intValue
        self.segmentationmapHeightSize = mlMultiArray.shape[1].intValue
    }
    
    subscript(colunmIndex: Int, rowIndex: Int) -> NSNumber {
        let index = colunmIndex*(segmentationmapHeightSize) + rowIndex
        return mlMultiArray[index]
    }
}

class DrawingSegmentationView: UIView {
    
    static private var colors: [Int32: UIColor] = [:]
    
    func segmentationColor(with index: Int32) -> UIColor {
        if let color = DrawingSegmentationView.colors[index] {
            return color
        } else {
            let color = UIColor(hue: CGFloat(index) / CGFloat(30), saturation: 1, brightness: 1, alpha: 0.5)
            DrawingSegmentationView.colors[index] = color
            return color
        }
    }
    
    var segmentationmap: SegmentationResultMLMultiArray? = nil {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        if let ctx = UIGraphicsGetCurrentContext() {
            
            ctx.clear(rect);
            
            guard let segmentationmap = self.segmentationmap else { return }
            
            let size = self.bounds.size
            let segmentationmapWidthSize = segmentationmap.segmentationmapWidthSize
            let segmentationmapHeightSize = segmentationmap.segmentationmapHeightSize
            let w = size.width / CGFloat(segmentationmapWidthSize)
            let h = size.height / CGFloat(segmentationmapHeightSize)
            
            for j in 0..<segmentationmapHeightSize {
                for i in 0..<segmentationmapWidthSize {
                    let value = segmentationmap[j, i].int32Value

                    let rect: CGRect = CGRect(x: CGFloat(i) * w, y: CGFloat(j) * h, width: w, height: h)

                    let color: UIColor = segmentationColor(with: value)

                    color.setFill()
                    UIRectFill(rect)
                }
            }
        }
    } // end of draw(rect:)
}

struct VisionDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Preview")
            VisionDetectionView()
        }
    }
}

