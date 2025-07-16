//
//  utilities.swift
//  SpectraPhone
//
//  Created by Alex Adams on 10/31/22.
//

import Foundation


class NumbersOnly: ObservableObject {
    @Published var value = "" {
        didSet {
            let filtered = value.filter { $0.isNumber||$0=="." }
            
            if value != filtered {
                value = filtered
            }
        }
    }
}


class MyStreamer{
    var fileHandle:FileHandle?
    var logPath: String?
    
    init(Prefix:String,modelName:String,fileIdentifier:String){
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(string: documentsDirectory)!
        let dataPath = docURL.appendingPathComponent(modelName)
        if !FileManager.default.fileExists(atPath: dataPath.absoluteString) {
            print("Folder do not exist")
            do {
                try FileManager.default.createDirectory(atPath: dataPath.absoluteString, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("ERROR in Logging"+error.localizedDescription)
            }
        }
        logPath = "\(dataPath)/\(Prefix)-\(fileIdentifier)-\(Date().toString(dateFormat: "dd-MM-YY_'at'_HH_mm_ss")).txt"
        if FileManager.default.fileExists(atPath: logPath!) == false{
            FileManager.default.createFile(atPath: logPath!, contents: nil, attributes: nil)
        }
        print(logPath!)
        fileHandle = FileHandle(forWritingAtPath: logPath!)
    }

    func write(_ string: String) {
//        print(fileHandle?.description ?? "nothing here")
        fileHandle?.seekToEndOfFile()
        if let data = string.data(using: String.Encoding.utf8){
            fileHandle?.write(data)
        }
    }
}




extension Date
{
    func toString( dateFormat format  : String ) -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }

}
