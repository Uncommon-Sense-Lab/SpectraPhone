//
//  CameraPhotoModel.swift
//  SpectraPhone
//
//  Created by Alex Adams on 10/31/22.
//



import Foundation
import AVFoundation
import SwiftUI
import UIKit
import CoreLocation
import Photos

public struct Photo: Identifiable, Equatable {
//    The ID of the captured photo
    public var id: String
//    Data representation of the captured photo
    public var originalData: Data
    
    public init(id: String = UUID().uuidString, originalData: Data) {
        self.id = id
        self.originalData = originalData
    }
}

public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?
    
    public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}

private enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}

public class CameraService:NSObject {
    typealias PhotoCaptureSessionID = String
    
//    MARK: Observed Properties UI must react to
//    1.
    @Published public var flashMode: AVCaptureDevice.FlashMode = .on
//    2.
    @Published public var shouldShowAlertView = false
//    3.
    @Published public var shouldShowSpinner = false
//    4.
    @Published public var willCapturePhoto = false
//    5.
    @Published public var isCameraButtonDisabled = true
//    6.
    @Published public var isCameraUnavailable = true
//    8.
    @Published public var photo: Photo?
    
    @Published public var maxISO = Float(250.0)
    
    @Published public var minISO = Float(250.0)
    
    @StateObject var model = CameraViewModel()
    
    public var alertError: AlertError = AlertError()
    
//    9. The capture session.
    public let session = AVCaptureSession()
    
//    10. Stores whether the session is running or not.
    private var isSessionRunning = false
    
//    11. Stores wether the session is been configured or not.
    private var isConfigured = false
    
//    12. Stores the result of the setup process.
    private var setupResult: SessionSetupResult = .success
    
//    13. The GDC queue to be used to execute most of the capture session's processes.
    private let sessionQueue = DispatchQueue(label: "camera session queue")
    
//    14. The device we'll use to capture video from.
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!

// MARK: Device Configuration Properties
//    15. Video capture device discovery session.
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTelephotoCamera], mediaType: .video, position: .back)

// MARK: Capturing Photos Properties
//    16. PhotoOutput. Configures and captures photos.
    private let photoOutput = AVCapturePhotoOutput()
    
//    17 Stores delegates that will handle the photo capture process's stages.
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    private var movieFileOutput: AVCaptureMovieFileOutput?

    
    public func configure() {
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    
    
    
    //        MARK: Checks for user's permisions
    public func checkForPermissions() {
      
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            // Store this result, create an alert error and tell the UI to show it.
            setupResult = .notAuthorized
            
            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Access", message: "SwiftCamera doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Settings", secondaryButtonTitle: nil, primaryAction: {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [:], completionHandler: nil)
                    
                }, secondaryAction: nil)
                self.shouldShowAlertView = true
                self.isCameraUnavailable = true
                self.isCameraButtonDisabled = true
            }
        }
    }
    
    
    //  MARK: Session Managment
        
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add video input.
        let devices = self.videoDeviceDiscoverySession.devices
        
        print(devices)
        
        do {
            var defaultVideoDevice: AVCaptureDevice?
            defaultVideoDevice=AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)

            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            do {
                try videoDevice.lockForConfiguration()

                if(videoDevice.isFocusModeSupported(AVCaptureDevice.FocusMode.locked)){
                    print("support lock focus")
                    videoDevice.focusMode = AVCaptureDevice.FocusMode.locked
                }
//
//                videoDevice.focusMode = AVCaptureDevice.FocusMode.autoFocus

                videoDevice.whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode.locked
                videoDevice.exposureMode = AVCaptureDevice.ExposureMode.custom
                
                if(videoDevice.isLowLightBoostSupported){
                    videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = false
                }
                videoDevice.unlockForConfiguration()
            }
            catch {
                print(error.localizedDescription)
                setupResult = .configurationFailed
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
//        // Add the photo output.
//        if session.canAddOutput(photoOutput) {
//            session.addOutput(photoOutput)
//            photoOutput.isAppleProRAWEnabled = true
//            self.photoOutput.isAppleProRAWEnabled = self.photoOutput.isAppleProRAWSupported
//            
//            photoOutput.maxPhotoQualityPrioritization = .quality
//            print(photoOutput.maxPhotoDimensions)
////            let modelName = UIDevice.current.model
////            print(modelName)
//            
//            photoOutput.maxPhotoDimensions =  self.photoOutput.maxPhotoDimensions
//
//
//            
//        } else {
//            print("Could not add photo output to the session")
//            setupResult = .configurationFailed
//            session.commitConfiguration()
//            return
//        }
        self.changeMode(videoOn: true)
        session.commitConfiguration()
        self.isConfigured = true

        self.start()



    }

    
    
    public func changeMode(videoOn:Bool){
        if(videoOn){
            sessionQueue.async {
                let movieFileOutput = AVCaptureMovieFileOutput()
                
                if self.session.canAddOutput(movieFileOutput) {
                    if(self.session.isRunning){
                        self.session.stopRunning()
                    }
                    self.session.beginConfiguration()
                    self.session.removeOutput(self.photoOutput)
                    self.session.addOutput(movieFileOutput)
                    self.session.sessionPreset = .hd4K3840x2160
            
                    self.movieFileOutput = movieFileOutput
                    self.session.commitConfiguration()
                    self.session.startRunning()
                }
            }
        }else{
            sessionQueue.async { [self] in
                if session.canAddOutput(photoOutput) {
                    if(session.isRunning){
                        session.stopRunning()
                    }
                    session.beginConfiguration()
                    session.removeOutput(movieFileOutput!)
                
                    session.addOutput(photoOutput)
                    session.sessionPreset = .photo
                    
//                    photoOutput.maxPhotoDimensions = .init(width: 8064, height: 6048)
                    photoOutput.maxPhotoDimensions  = self.photoOutput.maxPhotoDimensions
                    print(photoOutput.maxPhotoDimensions)
                    session.commitConfiguration()
                    session.startRunning()
                }
            }
        }
    }
    
    public func start() {
//        We use our capture session queue to ensure our UI runs smoothly on the main thread.
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            if !self.isSessionRunning && self.isConfigured {
                self.maxISO = device.activeFormat.maxISO
                self.minISO = device.activeFormat.minISO
               
                switch self.setupResult {
                case .success:
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                    
                    if self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = false
                            self.isCameraUnavailable = false
                        }
                    }
                    
                case .configurationFailed, .notAuthorized:
                    print("Application not authorized to use camera")

                    DispatchQueue.main.async {
                        self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or its missing permissions", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                        self.shouldShowAlertView = true
                        self.isCameraButtonDisabled = true
                        self.isCameraUnavailable = true
                    }
                }
            }
            
            self.setCaptureSetting(m_focus: 1.0, m_iso: 250, exposure: CMTimeMake(value: 1,timescale: Int32(30)))
            self.setTorch(to: 1.0)

        }
    }
    
    public func stop(completion: (() -> ())? = nil) {
           sessionQueue.async {
               if self.isSessionRunning {
                   if self.setupResult == .success {
                       self.session.stopRunning()
                       self.isSessionRunning = self.session.isRunning
                       
                       if !self.session.isRunning {
                           DispatchQueue.main.async {
                               self.isCameraButtonDisabled = true
                               self.isCameraUnavailable = true
                               completion?()
                           }
                       }
                   }
               }
           }
       }
    
    
    public func setTorch(to level: Float) {
        print("setting torch")
        let device = self.videoDeviceInput.device
        if(device.hasTorch){
            do{
                try device.lockForConfiguration()
                if level == 0 {
                    device.torchMode = .off
                } else {
                    device.torchMode = .on
                    try device.setTorchModeOn(level: level)
                }

                device.unlockForConfiguration()
            }catch{
                print(error.localizedDescription)
            }
        }else{
            print("no torch")
        }

    }
    
    
    
    //  MARK: Device Configuration

//    var cameraNumber = 0

    public func setCaptureSetting(m_focus: Float, m_iso:Float,exposure:CMTime){
        
        let device = self.videoDeviceInput.device
        
        do {
            try device.lockForConfiguration()
            
            if(device.isLockingFocusWithCustomLensPositionSupported){
                device.setFocusModeLocked(lensPosition: m_focus)
            }
            
//            print(device.activeFormat.maxExposureDuration)
            if (device.isExposureModeSupported(.custom)
                && m_iso>=device.activeFormat.minISO
                && m_iso<=device.activeFormat.maxISO
                && (exposure)>=device.activeFormat.minExposureDuration
                && (exposure)<=device.activeFormat.maxExposureDuration)
            {
                device.setExposureModeCustom(duration: exposure, iso: m_iso, completionHandler: { (time) in
                })
           
            }
            else{
                DispatchQueue.main.async {
                    self.alertError = AlertError(title: "Out of Range", message: "Setting out of range", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                    self.shouldShowAlertView = true
                    self.isCameraButtonDisabled = true
                    self.isCameraUnavailable = true
                }
            }
 
            device.unlockForConfiguration()
            
            print("focus: ", device.lensPosition)
            print("exposure: ", device.iso)
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    public func captureVideo(id:String,length:Int){

        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        if !movieFileOutput.isRecording{
            // Start recording video to a temporary file.
            let outputFileName = id + "_"+String(Int(NSDate().timeIntervalSince1970*1000))
            let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
            movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
            print("start recording")
            let dispatchAfter = DispatchTimeInterval.seconds(length)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + dispatchAfter) {  movieFileOutput.stopRecording()
                print("stop recording")
            }
        
        }else{
            movieFileOutput.stopRecording()
            print("stop recording")
            
        }
    }
    
    //    MARK: Capture Photo
      
      /// - Tag: CapturePhoto
    public func capturePhoto(id:String) {
          if self.setupResult != .configurationFailed {
              self.isCameraButtonDisabled = true
              
              sessionQueue.async {
//                  var photoSettings = AVCapturePhotoSettings()
                  
                  if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                      photoOutputConnection.videoOrientation = .portrait
                  }
                  let query = self.photoOutput.isAppleProRAWEnabled ?
                      { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) } :
                      { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
                  
                  // Retrieve the RAW format, favoring the Apple ProRAW format when it's in an enabled state.
                  guard let rawFormat =
                            self.photoOutput.availableRawPhotoPixelFormatTypes.first(where: query) else {
                      fatalError("No RAW format found.")
                  }
                  let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
                  print("capture settings")
                  self.photoOutput.maxPhotoDimensions = .init(width: 4032, height: 3024)  //iphone 12
//                  self.photoOutput.maxPhotoDimensions = .init(width: 8064, height: 6048)
                  photoSettings.maxPhotoDimensions =  self.photoOutput.maxPhotoDimensions

                  let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, id:id, willCapturePhotoAnimation: {

                  }, completionHandler: { (photoCaptureProcessor) in
                      // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                      if let data = photoCaptureProcessor.photoData {
                          self.photo = Photo(originalData: data)
                          print("passing photo")
                      } else {
                          print("No photo data")
                      }
                      
                      self.isCameraButtonDisabled = false
                      
                      self.sessionQueue.async {
                          self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                      }
                  }, photoProcessingHandler: { animate in
                      // Animates a spinner while photo is processing
                      if animate {
                          self.shouldShowSpinner = true
                      } else {
                          self.shouldShowSpinner = false
                      }
                  })
                  
                  // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
                  self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
                  self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
                    
              }
          }
      }
  }


extension CameraService: AVCaptureFileOutputRecordingDelegate{
    
    /// - Tag: DidFinishRecording
    public func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        print("in recording delegate")
        // Note: Because we use a unique file path for each recording, a new recording won't overwrite a recording mid-save.
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }
        }
        
        var success = true
        
        if error != nil {
            print("Movie file finishing error: \(String(describing: error))")
            success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
        }
        
        if success {
            print("success recording and is now saving")
            // Check the authorization status.
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    // Save the movie file to the photo library and cleanup.
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                        
                    }, completionHandler: { success, error in
                        if !success {
                            print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
                        }
                        cleanup()
                    }
                    )
                } else {
                    cleanup()
                }
            }
        } else {
            cleanup()
        }
    }
}
