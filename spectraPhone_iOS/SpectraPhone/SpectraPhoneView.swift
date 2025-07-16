//
//  ContentView.swift
//  SpectraPhone
//
//  Created by Alex Adams on 10/31/22.
//
import Foundation
import SwiftUI
import Combine
import AVFoundation


struct SpectraPhoneView: View {
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let t2 = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var counter = 5
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @StateObject var model = CameraViewModel()
    
    @State var currentZoomFactor: CGFloat = 1.0
    
    @State private var iso: String = "250"
    @State private var exposure: String = "30"
    @State private var focus: String = "1.0"
    @State private var zoom:String = "1"
    @State private var id: String = "test"
    @State private var torch:String = "1.0"
    @State private var videoCapture = true
    @State private var torchOn = true
    @State private var pulse = false
    @State private var burstN:String = "1"
    @State private var torchInterval:Float = 0.1
    @State private var capturelength:String = "10"
    @State private var timeRemaining:String = ""
    @State private var collapseSettings = false

    @State var cameraRec = false

    
//    func setPulse(){
//        let v = Float(capturelength) ?? 0.0
//        torchInterval = 1.0/v
//        print(torchInterval)
//        torch = "0.0"
//        model.setTorch(torch: torch)
//        torchOn = true
//        self.videoCapture = true
//        model.changemode(videoOn: true)
//                
//    }
    
    func triggerTorch(){
        if(torchOn){
            model.setTorch(torch: torch)
        }else{
            model.setTorch(torch: "0.0")
        }
    }
    func changeTorch(){
        var t = Float(torch) ?? 0.0
        t = t + torchInterval
        if(t > 1.0){
            t = 1.0
        }
        torch = String(t)
        print(torch)
        model.setTorch(torch: torch)
        
    }
 
    var captureButton: some View {
        Button(action: {
            
            if(videoCapture){
                torchOn = true
                model.setTorch(torch: torch)
                sleep(1)
                
                model.captureVideo(id:self.id, length: self.capturelength)
                cameraRec = true
                counter = Int(capturelength) ?? 0 + 1
                
            }else{
                model.capturePhoto(id: self.id)
            }
        }, label: {
            if(counter > 0 && cameraRec){
                Circle()
                    .foregroundColor(.red)
                    .frame(width: 80, height: 80, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.8), lineWidth: 2)
                            .frame(width: 65, height: 65, alignment: .center)
                    )
            }
            else{
                Circle()
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.8), lineWidth: 2)
                            .frame(width: 65, height: 65, alignment: .center)
                    )
            }
        }).onReceive(timer) { time in
            
            
            if(counter  > 0 && cameraRec){
              
                counter = counter - 1
                timeRemaining = String(counter + 1)
                print(counter)
            }else{
                counter = Int(capturelength) ?? 0 + 1
                cameraRec = false
                timeRemaining = ""
            }
        }
    }
    var dataID: some View{
        VStack{
            
            Toggle("Show Settings", isOn: $collapseSettings)
                .toggleStyle(.switch)
                .padding(.trailing, 10)
                .padding(.leading, 10)
            Divider()
            
            HStack {
                Text("ID")
                    .multilineTextAlignment(.leading)
                    .bold()
                    .foregroundColor(Color.blue)
                    .padding(.trailing, 10)
                    .padding(.leading, 10)
                
                Divider()
                
                TextField("id#, age, weight...", text:  $id).offset(x: 15)
                
                
                
            }
            
        }
    }
    var viewTime: some View{
        HStack{
            Text(timeRemaining)
                .font(.title)
                .multilineTextAlignment(.center)
                .bold()
                .foregroundColor(Color.red)
        }
    }
    var PictureSetting: some View {
        
                List{
                    HStack {
                        HStack {
                            Toggle("Video", isOn: $videoCapture)
                                .onChange(of: videoCapture) { _videoCapture in
                                    model.changemode(videoOn: _videoCapture)
                                }
                        }
                       
                        Divider()
                        HStack { Text("Length").bold().foregroundColor(Color.blue)
                            TextField("secs", text: $capturelength)//.offset(x: 15)
                        }
//
                    }
            
                   
                    HStack {
                        Toggle("Source", isOn: $torchOn)
                            .onChange(of: torchOn){newValue in
                                triggerTorch()
                            }
                        
                        Divider()
                        
                        Stepper {TextField("0-1", text: $torch)}
                       
                        onIncrement: {
                            
                            if(Float(torch)! + 0.1 <= 1.0){
                                
                                torch = String(round(Float(torch)!*10 + 1)/10.0);
                            }else{
                                torch = "1.0"
                            }
                            torchOn = true
                            model.setTorch(torch: torch)
                        }
                        onDecrement: {
                            
                            if(Float(torch)! - 0.1 >= 0.0){
                                torch = String(round(Float(torch)!*10 - 1)/10.0);
                            }else{
                                torch = "0.0"
                                torchOn = false
                            }
                            torchOn = true
                            model.setTorch(torch: torch)
                        }
                        
                    }

                    HStack {
                        Text("Focus").bold().foregroundColor(Color.green)
                        Stepper {
                            TextField("0-1", text: $focus).offset(x: 15)
                        }
                        onIncrement: {
                            if(Float(focus)! + 0.01 <= 1.0){
                                
                                focus = String(round(Float(focus)!*100 + 1)/100.0);
                            }else{
                                focus = "1.0"
                            }
                            model.setCameraConfiguration(man_focus: focus, man_iso: iso, exposure: exposure)
                        }
                        onDecrement: {
                            
                            if(Float(focus)! - 0.01 >= 0.0){
                                focus = String(round(Float(focus)!*100 - 1)/100.0);
                            }else{
                                torch = "0.0"
                            }
                            model.setCameraConfiguration(man_focus: focus, man_iso: iso, exposure: exposure)
                        }
                    }
            

                HStack {
                    
                    HStack {
                        Text("Iso").bold().foregroundColor(Color.green)
                        Stepper {
                            TextField("iso", text: $iso).offset(x: 5)
                        }
                        onIncrement: {
                            let mxIso = Int(model.service.maxISO)
                            if(Int(iso)! + 1 <= mxIso){
                            
                                iso = String(Int(iso)! + 1);
                                
//                                print("our ISO: %i", iso)
                            }else{
                                iso = String(mxIso)
                            }
                            model.setCameraConfiguration(man_focus: focus, man_iso: iso, exposure: exposure)
                        }
                        onDecrement: {
                            let mnIso = Int(model.service.minISO)
                            if(Int(iso)! - 1 >= mnIso){
                                iso = String(Int(iso)! - 1);
                            }else{
                                iso = String(mnIso)
                            }
                            model.setCameraConfiguration(man_focus: focus, man_iso: iso, exposure: exposure)
                    }
                }
            }
    


                HStack {
                        Text("Exposure").bold().foregroundColor(Color.green)
                        Stepper {
                            TextField("1-120", text: $exposure).offset(x: 5)
                        }
                        onIncrement: {
                            if(Int(exposure)! + 1 <= 120){
                                
                                exposure = String(Int(exposure)! + 1);
                            }else{
                                exposure = "120"
                            }
                            model.setCameraConfiguration(man_focus: focus, man_iso: iso, exposure: exposure)
                        }
                        onDecrement: {
                            if(Int(exposure)! - 1 >= 1){
                                
                                exposure = String(Int(exposure)! - 1);
                            }else{
                                exposure = "1"
                            }
                            model.setCameraConfiguration(man_focus: focus, man_iso: iso, exposure: exposure)
                            }
                            
                        }
                
                    }
                
    }
    
    var body: some View {
        
        GeometryReader { reader in
            
            VStack{

                ZStack{
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    CameraPhotoPreview(session: model.session)
                        .onAppear {
                            model.configure()
                        }
                        
                        .alert(isPresented: $model.showAlertError, content: {
                            Alert(title: Text(model.alertError.title), message: Text(model.alertError.message), dismissButton: .default(Text(model.alertError.primaryButtonTitle), action: {
                                model.alertError.primaryAction?()
                            }))
                        })
                } .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                  )
                if(collapseSettings){
                    PictureSetting.frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: 275,
                        alignment: .topLeading
                    )
                    
                    Divider()
                }
                dataID.frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: 70,
                        alignment: .center
                    )
                
                Divider()
                
                viewTime.frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: 50,
                    alignment: .center
                )
 
                Divider()
                    captureButton.frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: 70,
                        alignment: .center
                    )

            }
        }
        
    }
    
}
struct VerticalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        return VStack(alignment: .leading) {
            configuration.label // <1>
                .font(.system(size: 22, weight: .semibold)).lineLimit(2)
            HStack {
                if configuration.isOn { // <2>
                    Text("On")
                } else {
                    Text("Off")
                }
                Spacer()
                Toggle(configuration).labelsHidden() // <3>
            }
        }
        .frame(width: 100)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(configuration.isOn ? Color.green: Color.gray, lineWidth: 2) // <4>
        )
    }
}

struct PhotoCameraPreview: UIViewRepresentable {
    // 1.
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
             AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    // 2.
    let session: AVCaptureSession
    
    // 3.
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.cornerRadius = 0
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.connection?.videoOrientation = .portrait

        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }

}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SpectraPhoneView()
    }
}

class UserSettings: ObservableObject{
    //
    @Published var screenFlashRate = NumbersOnly()
    @Published var cameraCaptureRate = NumbersOnly()
//    @Published var experimentTime = NumbersOnly()
    @Published var exposureTime = NumbersOnly()
    @Published var iso = NumbersOnly()
    @Published var zoomFactor = NumbersOnly()
    @Published var torch = NumbersOnly()
    @Published var cameraNumber = NumbersOnly()
   
    @Published var userID:String = ""
    @Published var frontCamera:Bool = false
    @Published var teleCamera:Bool = false
    
    @Published var FlashColor1 = Color(red: 1, green: 0, blue: 0)
    @Published var FlashColor2 = Color(red: 0, green: 0, blue: 1)
}
