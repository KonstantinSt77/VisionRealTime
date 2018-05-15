//
//  ViewController.swift
//  CoreMLSample
//
//  Created by Kostya on 18.04.2018.
//  Copyright © 2018 K.S. All rights reserved.
//

import UIKit
import CoreMedia
import Vision

class MainViewController: UIViewController, UIImagePickerControllerDelegate {
    
    @IBOutlet private weak var predictLabel: UILabel!
    @IBOutlet private weak var trustedLabel: UILabel!
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var focusedView: UIView!
    let inceptionv3model = Inceptionv3()
    private var videoCapture: VideoCapture!
    private var requests = [VNRequest]()
    var type : String!
    var eps : String!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.navigationItem.title = self.type + " OFF!"
        
        self.focusedView.layer.cornerRadius = 10
        self.predictLabel.layer.cornerRadius = 10
        self.previewView.layer.cornerRadius = 10
        
        let spec = VideoSpec(fps: 5, size: CGSize(width: 299, height: 299))
        
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: previewView.layer)
        
        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer) in

        DispatchQueue.main.async {
            self.focusedView.backgroundColor = UIColor.clear
            self.focusedView.layer.borderColor = UIColor.green.cgColor
            self.focusedView.layer.borderWidth = 2.0
            self.focusedView.isHidden = true
            self.trustedLabel.text = ""
        }
       
        if(self.type=="vision")
        {
            self.setupVision()
            self.handleImageBufferWithVision(imageBuffer: imageBuffer)
        }
        else
        {
            self.navigationItem.title = self.type + " ON!"
            self.handleImageBufferWithCoreML(imageBuffer: imageBuffer)
        }}
    }
        
    func handleImageBufferWithCoreML(imageBuffer: CMSampleBuffer)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else
        {
            return
        }
        do
        {
            let prediction = try self.inceptionv3model.prediction(image: self.resize(pixelBuffer: pixelBuffer)!)
            DispatchQueue.main.async
            {
                if let prob = prediction.classLabelProbs[prediction.classLabel]
                {
                    self.predictLabel.text = "\(prediction.classLabel) \(String(describing: prob))"
                    print("%" + String(describing: prob))
                    let percentD = Float(prob) as Float
                    let epsD = Float(self.eps)!
                    
                    if(percentD > epsD)
                    {
                        self.videoCapture.stopCapture()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                             self.predictionCorrect(pred: "\(prediction.classLabel)")
                        })
                    }
                }
            }
        }
        catch let error as NSError
        {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
    }
    
    func predictionCorrect(pred : String)
    {
        DispatchQueue.main.async
        {
            self.focusedView.isHidden = false
            self.trustedLabel.isHidden = false
            self.trustedLabel.text = "It's a "+pred
            self.trustedLabel.layer.cornerRadius = 30
        }
    }
    
    func handleImageBufferWithVision(imageBuffer: CMSampleBuffer)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else
        {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let cameraIntrinsicData = CMGetAttachment(imageBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil)
        {
            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: UInt32(self.exifOrientationFromDeviceOrientation))!, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    func setupVision()
    {
        self.navigationItem.title = self.type + " ON!"
        
        guard let visionModel = try? VNCoreMLModel(for: inceptionv3model.model) else {
            fatalError("can't load Vision ML model")
        }
        let classificationRequest = VNCoreMLRequest(model: visionModel) { (request: VNRequest, error: Error?) in
            guard let observations = request.results else {
                print("no results:\(error!)")
                return
            }
            
            let classifications = observations[0...4]
                .compactMap({ $0 as? VNClassificationObservation })
                .filter({ $0.confidence > 0.2 })
                .map({ "\($0.identifier) \($0.confidence)" })
            DispatchQueue.main.async {
                self.predictLabel.text = classifications.joined(separator: "\n")
            }
        }
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        
        self.requests = [classificationRequest]
    }
    
    var exifOrientationFromDeviceOrientation: Int32 {
        let exifOrientation: DeviceOrientation
        enum DeviceOrientation: Int32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = .top0ColLeft
        case .landscapeRight:
            exifOrientation = .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
    
    func resize(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let imageSide = 299
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        let transform = CGAffineTransform(scaleX: CGFloat(imageSide) / CGFloat(CVPixelBufferGetWidth(pixelBuffer)), y: CGFloat(imageSide) / CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        ciImage = ciImage.transformed(by: transform).cropped(to: CGRect(x: 0, y: 0, width: imageSide, height: imageSide))
        let ciContext = CIContext()
        var resizeBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, imageSide, imageSide, CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &resizeBuffer)
        ciContext.render(ciImage, to: resizeBuffer!)
        return resizeBuffer
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let videoCapture = videoCapture else {return}
        videoCapture.startCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else {return}
        videoCapture.resizePreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
