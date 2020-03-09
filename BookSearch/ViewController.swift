//
//  ViewController.swift
//  BookSearch
//
//  Created by 佐藤　泰利 on 2020/03/09.
//  Copyright © 2020 佐藤　泰利. All rights reserved.
//

import UIKit
import AVFoundation

struct SearchResut: Codable {
    let kind:String
    let items:[Item]
}

struct Item: Codable{
    let volumeInfo:VolumeInfo
//    let authors: [String]
}

struct VolumeInfo: Codable{
    let title:String
    let description:String
    let authors: [String]
}

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureDevice:AVCaptureDevice?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var captureSession:AVCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.requestApi(isbnText: "4309416217")
        navigationItem.title = "Scanner"
        view.backgroundColor = .white

        captureDevice = AVCaptureDevice.default(for: .video)
        // Check if captureDevice returns a value and unwrap it
        if let captureDevice = captureDevice {

            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)

                captureSession = AVCaptureSession()
                guard let captureSession = captureSession else { return }
                captureSession.addInput(input)

                let captureMetadataOutput = AVCaptureMetadataOutput()
                captureSession.addOutput(captureMetadataOutput)

                captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                captureMetadataOutput.metadataObjectTypes = [.code128, .qr, .ean13,  .ean8, .code39]

                captureSession.startRunning()

                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                videoPreviewLayer?.videoGravity = .resizeAspectFill
                videoPreviewLayer?.frame = view.layer.bounds
                view.layer.addSublayer(videoPreviewLayer!)

            } catch {
                print("Error Device Input")
            }

        }

        view.addSubview(codeLabel)
        codeLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        codeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        codeLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
        codeLabel.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    let codeLabel:UILabel = {
        let codeLabel = UILabel()
        codeLabel.backgroundColor = .white
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        return codeLabel
    }()

    let codeFrame:UIView = {
        let codeFrame = UIView()
        codeFrame.layer.borderColor = UIColor.green.cgColor
        codeFrame.layer.borderWidth = 2
        codeFrame.frame = CGRect.zero
        codeFrame.translatesAutoresizingMaskIntoConstraints = false
        return codeFrame
    }()

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        captureSession?.stopRunning()
        guard let objects = metadataObjects as? [AVMetadataObject] else { return }
        var detectionString: String? = nil
        let barcodeTypes = [AVMetadataObject.ObjectType.ean8, AVMetadataObject.ObjectType.ean13]
        for metadataObject in objects {
            loop: for type in barcodeTypes {
                guard metadataObject.type == type else { continue }
                guard self.videoPreviewLayer?.transformedMetadataObject(for: metadataObject) is AVMetadataMachineReadableCodeObject else { continue }
                if let object = metadataObject as? AVMetadataMachineReadableCodeObject {
                    detectionString = object.stringValue
                    break loop
                }
            }
            var text = ""
            guard let value = detectionString else { continue }
            text += "読み込んだ値:\t\(value)"
            text += "\n"
            guard let isbn = convartISBN(value: value) else { continue }
            text += "ISBN:\t\(isbn)"
            print("text \(text)")
            
            // APIを叩きに行く
            requestApi(isbnText: isbn)

        }



    }
    
    private func requestApi(isbnText: String) -> Bool {
        //日本語入力はエンコードしないとだめです。
        //検索キーワードをURLエンコードする
        guard let keyword_encode = isbnText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else{
            // 空だったらエラー
            return false
        }
        //エンドポイントへのリクエスト パラメーターをq=で渡している。
        //リクエストURL作成
        guard let req_url = URL(string: "https://www.googleapis.com/books/v1/volumes?q=\(keyword_encode)") else{
            return false
            
        }
        //先程のurlをURLRequest型へ、ここ結構ハマりました。
        let request = NSMutableURLRequest(url: req_url) as URLRequest
        //ここはアップルのリファレンスを参照①
        let task = URLSession.shared.dataTask(with: request){ (data, response, error) in
            //中身をチェック
            print(keyword_encode)
            print(req_url)
            do{
                let data = try Data(contentsOf: req_url)
                let searchResult = try JSONDecoder().decode(SearchResut.self, from: data)
                //searchResultに帰ってきたのを一つ一つ詰め込む。
                let result = searchResult.items
                for item in searchResult.items {
                    //ここでAPIを分解。分解している構造体は参照②
                    let volumeInfo = item.volumeInfo
                    let title = volumeInfo.title
                    let description = volumeInfo.description
                }
            }catch{
                print("エラーが出ました")
                
            }
            
        }
        task.resume()
        return true
    }
    
    private func convartISBN(value: String) -> String? {
        let v = NSString(string: value).longLongValue
        let prefix: Int64 = Int64(v / 10000000000)
        guard prefix == 978 || prefix == 979 else { return nil }
        let isbn9: Int64 = (v % 10000000000) / 10
        var sum: Int64 = 0
        var tmpISBN = isbn9

        var i = 10
        while i > 0 && tmpISBN > 0 {
            let divisor: Int64 = Int64(pow(10, Double(i - 2)))
            sum += (tmpISBN / divisor) * Int64(i)
            tmpISBN %= divisor
            i -= 1
        }

        let checkdigit = 11 - (sum % 11)
        return String(format: "%lld%@", isbn9, (checkdigit == 10) ? "X" : String(format: "%lld", checkdigit % 11))
    }

}
