//
//  CameraModel.swift
//  SpectraPhone
//
//  Created by Alex Adams on 10/31/22.
//

import SwiftUI
import AVFoundation
import UIKit

enum CameraError: Error {
    case invalidrange
}

struct CameraSetting{
    var frontCamear:Bool
//    var telephotoCamera:Bool
    var cameraNumber: Double
    var zoomfactor:Double
    var fps: Double
    var iso: Double
    var exposureTime: Double
}

class CameraModel: NSObject,ObservableObject,AVCaptureVideoDataOutputSampleBufferDelegate{

    
    @Published var session = AVCaptureSession()

    @Published var alert = false

    // since were going to read pic data....
    @Published var output = AVCaptureVideoDataOutput()
    
    // preview....
    @Published var preview : AVCaptureVideoPreviewLayer!

    // Pic Data...

    @Published var picData = Data(count: 0)
    
    @Published var heartRatesShow_red:[Double] = Array(repeating:0.0, count:100)
    //    @Published var heartRatesShow_blue:[Double] = Array(repeating:0.0, count:100)
    
    var view:UIView?
    var device: AVCaptureDevice?
    
    @Published var flash:Float = 0
    @Published var isSaving = false
    
    var sessionRunning = false
    var myStream: MyStreamer?
    
    public func setTorch(to level: Float) {
        print("setting torch")
        if (device != nil){
            do{
                try device!.lockForConfiguration()
                if level == 0 {
                    device!.torchMode = .off
                } else {
                    device!.torchMode = .on
                    try device!.setTorchModeOn(level: level)
                }

                device!.unlockForConfiguration()
                flash = level
            }catch{
                print(error)
                fatalError()
            }
            print("setting torch success")
        }else{
            print("setting torch fail")
        }

    }

    
    func startSaving(userID:String,modelName:String,fileIdentifier: String){
        if(!isSaving){
            isSaving = true
            myStream = MyStreamer(Prefix: "Camera_"+userID,modelName:modelName, fileIdentifier:fileIdentifier)
            print("Camera Recording Started")
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + experimentTime) {
//            print("Camera Recording Stopping")
//            self.isSaving = false
//        }
    }
    
    func stopSaving(){
        self.isSaving = false
        print("Camera Recording Stopping")
    }
    
    func check(cSetting:CameraSetting, preview:Bool)->Int{
        print("checking")
        var result:Int = -1
        // first checking camerahas got permission...
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            
            result =  setUp(cSetting:cSetting, preview: preview)
            // Setting Up Session
        case .notDetermined:
            // retusting for permission....
            AVCaptureDevice.requestAccess(for: .video) { (status) in

                if status{
                    result = self.setUp(cSetting:cSetting, preview:preview)
                }
            }
        case .denied:
            self.alert.toggle()
            result =  2

        default:
            result =  2
        }
        
        return result
    }

    func setUp(cSetting:CameraSetting, preview:Bool)->Int{

        // setting up camera...

        do{

            // setting configs...
            self.session.beginConfiguration()

            // change for your own...
//            if (cSetting.frontCamear){
//                device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
//                
//            }else{
//                let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera,.builtInUltraWideCamera,.builtInTelephotoCamera], mediaType: .video, position: .back)
//                
//                let devices = videoDeviceDiscoverySession.devices
//                
//                let index = Int(cSetting.cameraNumber) % devices.count
//                
//                device = devices[index]
                
                device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                
//                if (cSetting.telephotoCamera){
//                    device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
//                }
//                else {
//                    device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
//                }
//            }
            
            //setTorch(to: flash)
            
            let input = try AVCaptureDeviceInput(device: device!)

            // checking and adding to session...

            if self.session.canAddInput(input){
                self.session.addInput(input)
            }
            
            let dataOutputQueue = DispatchQueue(label: "video data queue",
                                                qos: .userInitiated,
                                                attributes: [],
                                                autoreleaseFrequency: .workItem)
            
//            let videoOutput = AVCaptureVideoDataOutput()
            
            output.setSampleBufferDelegate(self,
                                                queue: dataOutputQueue)
            
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            
            output.alwaysDiscardsLateVideoFrames = false
            
            // same for output....

            if self.session.canAddOutput(output){
                self.session.addOutput(output)
            }

            
            var bestFormat: AVCaptureDevice.Format?
            var maxRate: AVFrameRateRange?
            for format in device!.formats {
                
                if (CMFormatDescriptionGetMediaSubType(format.formatDescription) == 875704422){
    //                print("Format:")
    //                print(format.formatDescription)
    //                print(format.hashValue)
                    for range in format.videoSupportedFrameRateRanges {

                        if maxRate?.maxFrameRate ?? 0 < range.maxFrameRate {
                            maxRate = range
                            bestFormat = format
                        }
                    }
                }
            }
            if let bestFormat = bestFormat, let maxRange = maxRate {
                do {
                    try device!.lockForConfiguration()
                    device!.activeFormat = bestFormat
                    let duration = maxRange.minFrameDuration
                    print("duration:")
                    print(duration)
                    let  t:CMTime = CMTimeMake(value: 1, timescale: Int32(cSetting.fps));
                    device!.activeVideoMaxFrameDuration = t
                    device!.activeVideoMinFrameDuration = t
                    if(device!.isFocusModeSupported(AVCaptureDevice.FocusMode.locked)){
                        print("support lock focus")
                        device!.focusMode = AVCaptureDevice.FocusMode.locked
                    }
                    
                    device!.whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode.locked
                    if(device!.isLowLightBoostSupported){
                        device!.automaticallyEnablesLowLightBoostWhenAvailable = false
                    }
                    
                    
                    print(bestFormat.minISO)
                    print(bestFormat.maxISO)
                    print(bestFormat.minExposureDuration)
                    print(bestFormat.maxExposureDuration)
                    print("myfps " + String(cSetting.fps))
                    print("myIso " + String(cSetting.iso))
                    
                    var iso = Float(cSetting.iso)
                    
                    if (iso > bestFormat.maxISO ){
                        iso = bestFormat.maxISO
                    }
                    
                    print(iso)
                    
                    if (Float(cSetting.iso)>bestFormat.maxISO || Float(cSetting.iso)<bestFormat.minISO) {
                        throw CameraError.invalidrange
                    }
                    device!.setExposureModeCustom(duration: CMTimeMake(value: 1,timescale: Int32(cSetting.exposureTime)), iso: iso, completionHandler: { (time) in
                    })
                    
                    let minZoomFactor: CGFloat = device?.minAvailableVideoZoomFactor ?? 1.0
                    let maxZoomFactor: CGFloat = device?.maxAvailableVideoZoomFactor ?? 1.0
                    
                    print("zoom factor")
                    print(minZoomFactor)
                    print(maxZoomFactor)
//                    if #available(iOS 13.0, *) {
//                        if device?.deviceType == .builtInDualWideCamera || captureDevice?.deviceType == .builtInTripleCamera || captureDevice?.deviceType == .builtInUltraWideCamera {
//                            minZoomFactor = 0.5
//                        }
//                    }
                    
//                    var zoomScale = max(minZoomFactor, min(beginZoomScale * scale, maxZoomFactor))
                    device!.videoZoomFactor = CGFloat(cSetting.zoomfactor)

                    
                    
                    device!.unlockForConfiguration()
                    
            } catch {
                print(error.localizedDescription)
                return -1
                }
            }


            self.session.commitConfiguration()
            
            print("done set up")

            if !preview{
                self.session.startRunning()
            }
            return 1
        }
        catch{
            print(error.localizedDescription)
            return -1
        }
    }
    
  

        
//        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer,
                                     CVPixelBufferLockFlags.readOnly)

//        print("got a new frame")

        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                       CVPixelBufferLockFlags.readOnly)
    }
    
    
//    @objc private func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
//        var allTouchesOnPreviewLayer = true
//        let numTouch = recognizer.numberOfTouches
//
//        for i in 0 ..< numTouch {
//            let location = recognizer.location(ofTouch: i, in: view)
//            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
//            if !previewLayer.contains(convertedTouch) {
//                allTouchesOnPreviewLayer = false
//                break
//            }
//        }
//        if allTouchesOnPreviewLayer {
//            zoom(recognizer.scale)
//        }
//    }
    
    
// take and retake functions...
    
//    func takePic(){
//
//        self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
//
//        DispatchQueue.global(qos: .background).async {
//
//            self.session.stopRunning()
//
//            DispatchQueue.main.async {
//
//                withAnimation{self.isTaken.toggle()}
//            }
//        }
//    }

//    func reTake(){
//
//        DispatchQueue.global(qos: .background).async {
//
//            self.session.startRunning()
//
//            DispatchQueue.main.async {
//                withAnimation{self.isTaken.toggle()}
//                //clearing ...
//                self.isSaved = false
//                self.picData = Data(count: 0)
//            }
//        }
//    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if error != nil{
            return
        }

        print("pic taken...")

        guard let imageData = photo.fileDataRepresentation() else{return}

        self.picData = imageData
    }

//    func savePic(){
//
//        guard let image = UIImage(data: self.picData) else{return}
//
//        // saving Image...
//        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
//
//        self.isSaved = true
//
//        print("saved Successfully....")
//    }
}

// setting view for preview...

struct CameraPreview: UIViewRepresentable {

    @ObservedObject var camera : CameraModel
    
    var wide:Float = 0.45
    var height:Float = 0.3
    
    func makeUIView(context: Context) ->  UIView {
        if(!camera.sessionRunning){
            print("making view and camera session")
            camera.view = UIView(frame: CGRect(x:0, y:0, width: UIScreen.main.bounds.size.width*CGFloat(wide), height: UIScreen.main.bounds.height*CGFloat(height)))

            camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
            camera.preview.frame = camera.view!.frame

            // Your Own Properties...
            camera.preview.videoGravity = .resizeAspectFill
            camera.view!.layer.addSublayer(camera.preview)

            // starting session
            camera.session.startRunning()
            camera.sessionRunning = true
            return camera.view!
        }else{
            return camera.view!
        }

    }

    func updateUIView(_ uiView: UIView, context: Context) {
//        print("updateing")
    }
}



//extension UIImage {
//    var averageColor: UIColor? {
//        guard let inputImage = CIImage(image: self) else { return nil }
//        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
//
//        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
//        guard let outputImage = filter.outputImage else { return nil }
//
//        var bitmap = [UInt8](repeating: 0, count: 4)
//        let context = CIContext(options: [.workingColorSpace: kCFNull])
//        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
//
//        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
//    }
//}


