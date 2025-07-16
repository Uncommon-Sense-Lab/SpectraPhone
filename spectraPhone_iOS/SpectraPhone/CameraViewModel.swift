//
//  CameraViewModel.swift
//  SpectraPhone
//
//  Created by Alex Adams on 10/31/22.
//


import Combine
import AVFoundation

final class CameraViewModel: ObservableObject {
    
    public let service = CameraService()
    
    @Published var recording = false
    
    @Published var photo: Photo!
    
    @Published var showAlertError = false
    
    @Published var isFlashOn = false
    
    var alertError: AlertError!
    
    var session: AVCaptureSession
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        self.session = service.session
        
        service.$photo.sink { [weak self] (photo) in
            guard let pic = photo else { return }
            self?.photo = pic
        }
        .store(in: &self.subscriptions)
        
        service.$shouldShowAlertView.sink { [weak self] (val) in
            self?.alertError = self?.service.alertError
            self?.showAlertError = val
        }
        .store(in: &self.subscriptions)
        
        service.$flashMode.sink { [weak self] (mode) in
            self?.isFlashOn = mode == .on
        
        }
        .store(in: &self.subscriptions)
    
        service.changeMode(videoOn:true)
        
    }
    
    func configure() {
        service.checkForPermissions()
        service.configure()
    }
    
    func capturePhoto(id:String) {
        service.capturePhoto(id: id)
    }
        
    func setCameraConfiguration(man_focus: String, man_iso:String, exposure:String){
        service.setCaptureSetting(m_focus:Float(man_focus) ?? 1.0, m_iso: Float(man_iso) ?? 100.0, exposure:CMTimeMake(value: 1,timescale: Int32(exposure) ?? 2))
    }
    
  
    func switchFlash() {
        service.flashMode = service.flashMode == .on ? .off : .on
    }
    
    func setTorch(torch:String){
        let theTorch:Float = Float(torch) ?? 1.0
        if theTorch>=0 && theTorch<=1{
            service.setTorch(to: Float(torch) ?? 0)
           
        }
    }
    
    func changemode(videoOn:Bool){
        service.changeMode(videoOn:videoOn)
    }
    
    func captureVideo(id:String, length:String){
       
        service.captureVideo(id: id, length: Int(length) ?? 10)
    }

}

