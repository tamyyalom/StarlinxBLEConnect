//
//  UpdateTagVersion.swift
//  lynx
//
//  Created by rivki glick on 15/06/2021.
//

import Foundation

class UpdateTagVersion {

    class func loadFileSync(url: NSURL, completion:(_ path: String, _ error:NSError?) -> Void) {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first! as NSURL
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent!)
        if FileManager().fileExists(atPath: destinationUrl!.path) {
            print("file already exists [\(destinationUrl?.path ?? "")]")
            completion(destinationUrl!.path, nil)
        } else if let dataFromURL = NSData(contentsOf: url as URL){
            if dataFromURL.write(to: destinationUrl!, atomically: true) {
                print("file saved [\(destinationUrl?.path ?? "")]")
                completion((destinationUrl?.path)!, nil)
            } else {
                print("error saving file")
                let error = NSError(domain:"Error saving file", code:1001, userInfo:nil)
                completion(destinationUrl!.path, error)
            }
        } else {
            let error = NSError(domain:"Error downloading file", code:1002, userInfo:nil)
            completion(destinationUrl!.path, error)
        }
    }

//    class func loadFileAsync(url: NSURL, completion:(_ path:String, _ error:NSError?) -> Void) {
//        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first! as NSURL
//        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent!)
//        if FileManager().fileExists(atPath: destinationUrl?.path ?? "") {
//            print("file already exists [\(destinationUrl?.path ?? "")]")
//            completion(destinationUrl!.path, nil)
//        } else {
//            let sessionConfig = URLSessionConfiguration.default
//            let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
//            let request = NSMutableURLRequest(url: url as URL)
//            request.httpMethod = "GET"
//            let task = session.dataTaskWithRequest(request as URLRequest, completionHandler: { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
//                if (error == nil) {
//                    if let response = response as? NSHTTPURLResponse {
//                        println("response=\(response)")
//                        if response.statusCode == 200 {
//                            if data.writeToURL(destinationUrl, atomically: true) {
//                                println("file saved [\(destinationUrl.path!)]")
//                                completion(path: destinationUrl.path!, error:error)
//                            } else {
//                                println("error saving file")
//                                let error = NSError(domain:"Error saving file", code:1001, userInfo:nil)
//                                completion(path: destinationUrl.path!, error:error)
//                            }
//                        }
//                    }
//                }
//                else {
//                    println("Failure: \(error.localizedDescription)");
//                    completion(path: destinationUrl.path!, error:error)
//                }
//            })
//            task.resume()
//        }
//    }
}
