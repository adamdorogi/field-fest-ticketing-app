//
//  ViewController.swift
//  FieldFestTicket
//
//  Created by Adam Dorogi-Kaposi on 9/2/18.
//  Copyright © 2018 Adam Dorogi-Kaposi. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var video = AVCaptureVideoPreviewLayer()
    
    // Define capture device.
    let device = AVCaptureDevice.default(for: .video)
    
    let scanButton = UIButton(type: .system)
    
    let statusView = UIView()
    let blurEffectView = UIVisualEffectView()
    let dismissButton = UIButton(type: .system)
    
    let greenColor = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1.0)
    let redColor = UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0)
    
    let animationDuration = 0.5
    
    var flashButton = UIBarButtonItem()
    var isFlashOn = Bool()
    
    // Scanned code.
    var code = String()
    
    var fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("tickets.txt")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create session.
        let session = AVCaptureSession()
        
        // Add flash button.
        flashButton.tintColor = .white
        flashButton.target = self
        flashButton.action = #selector(flash)
        flashButton.image = #imageLiteral(resourceName: "flashOff")
        navigationItem.rightBarButtonItem  = flashButton
        
        let infoButton = UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(ticketManager))
        infoButton.tintColor = .white
        navigationItem.leftBarButtonItem = infoButton
        
        do {
            // Define input.
            let input = try AVCaptureDeviceInput(device: device!)
            session.addInput(input)
        } catch {
            print("Could not define input.")
        }
        
        // Define output.
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        
        // Process output on main queue.
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Only interested in QR codes.
        output.metadataObjectTypes = [.qr]
        
        // Display video.
        video = AVCaptureVideoPreviewLayer(session: session)
        video.frame = view.layer.bounds
        view.layer.addSublayer(video)
        
        session.startRunning()
        
        // Set up button.
        enableScanButton(enable: false)
        
        scanButton.setImage(#imageLiteral(resourceName: "scan"), for: .normal)
        
        scanButton.frame.size.width = 64
        scanButton.frame.size.height =  scanButton.frame.width
        
        scanButton.frame.origin.x = view.frame.width / 2 - scanButton.frame.width / 2
        scanButton.frame.origin.y = view.frame.height - 2 * scanButton.frame.height
        
        scanButton.addTarget(self, action: #selector(checkTicket), for: .touchUpInside)
        
        scanButton.layer.shadowRadius = scanButton.frame.width / 4
        scanButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        scanButton.layer.shadowOpacity = 0.5
        
        view.addSubview(scanButton)
    }
    
    @objc func flash() {
        isFlashOn = !isFlashOn
        
        do {
            try device?.lockForConfiguration()
            
            if isFlashOn {
                flashButton.image = #imageLiteral(resourceName: "flashOn")
                device?.torchMode = .on
            } else {
                flashButton.image = #imageLiteral(resourceName: "flashOff")
                device?.torchMode = .off
            }
            
            device?.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
    
    func enableScanButton(enable: Bool) {
        if enable {
            scanButton.isEnabled = true
            scanButton.alpha = 1
        } else {
            scanButton.isEnabled = false
            scanButton.alpha = 0.5
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if metadataObjects.count == 0 {
            // No QR code found.
            enableScanButton(enable: false)
            return
        }
        
        // QR code found.
        enableScanButton(enable: true)
        
        if let object = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
            if object.type == .qr {
                code = object.stringValue!
            }
        }
    }
    
    @objc func checkTicket() {
        // Separate code into ticket information
        let ticketInfo = code.components(separatedBy: "-")
        
        // If code doesn't consists of 3 fields, error.
        if ticketInfo.count != 3 {
            ticketStatus(success: false)
            return
        }
        
        // Assign ticket infos
        let orderId = ticketInfo[0]
        let lineItemId = Int(ticketInfo[1])
        let sequenceId = Int(ticketInfo[2])
        
        // URL of JSON file for order
        let orderUrl = URL(string: "https://100d4825e2638deb085cb8160f242622:b80ecfc47e6a14f3bb7b3921c81a8f4e@fieldfest.myshopify.com/admin/orders/\(orderId).json?fields=line_items")
        
        var ticketCodes = String()
        
        do {
            // Check duplicates.
            ticketCodes = try String(contentsOf: fileURL!, encoding: .utf8)
            
            if ticketCodes.contains("\(code)\n") {
                ticketStatus(success: false)
                return
            }
        } catch {
            ticketCodes = ""
            try! "".write(to: fileURL!, atomically: false, encoding: .utf8)
        }
        
        do {
            // Read JSON file
            let orderJson = try readJson(url: orderUrl!)
            
            // Create dictionary line items.
            var lineItems = [Int: [Any]]()
            
            for lineItem in (orderJson["order"] as! [String:Any])["line_items"] as! [[String:Any]] {
                // Map each line item quantity to its line item ID.
                lineItems[lineItem["id"] as! Int] = [lineItem["quantity"] as! Int, lineItem["title"] as! String]
            }
            
            // If scanned code's line item ID is not found,
            // or if sequence ID is larger than one less of quantity, then error
            if lineItems[lineItemId!] == nil || sequenceId! > (lineItems[lineItemId!]![0] as! Int) - 1 {
                ticketStatus(success: false)
                return
            }
            
            ticketStatus(success: true, title: lineItems[lineItemId!]![1] as! String)
            saveTicket(code: code)
        } catch {
            // No such order exists (couldn't read JSON file)
            ticketStatus(success: false)
        }
    }
    
    func ticketStatus(success: Bool, title: String = "") {
        var statusColor = UIColor()
        var headerText = String()
        var ticketImage = UIImage()
        var descriptionText = String()
        var dismissImage = UIImage()
        
        // Check scan status.
        if success {
            statusColor = greenColor
            headerText = "Siker!"
            ticketImage = #imageLiteral(resourceName: "ticketSuccess")
            descriptionText = "Sikeresen leszkennelve!"
            dismissImage = #imageLiteral(resourceName: "successDismiss")
        } else {
            statusColor = redColor
            headerText = "Baj van!"
            ticketImage = #imageLiteral(resourceName: "ticketError")
            descriptionText = "A leszkennelt jegy nem érvényes."
            dismissImage = #imageLiteral(resourceName: "errorDismiss")
        }
        
        // Add blur effect.
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView.effect = blurEffect
        blurEffectView.frame = view.bounds
        
        // Animate statusView.
        blurEffectView.alpha = 0.0
        
        UIView.animate(withDuration: animationDuration / 2) {
            self.blurEffectView.alpha = 1.0
        }
        
        view.addSubview(blurEffectView)
        
        // Set up status view.
        statusView.backgroundColor = statusColor
        
        statusView.frame.size = CGSize(width: view.frame.width * 4 / 5,
                                      height: view.frame.height * 2 / 3)
        
        statusView.frame.origin = CGPoint(x: view.frame.width / 2 - statusView.frame.width / 2,
                                         y: view.frame.height / 2 - statusView.frame.height / 2)
        
        statusView.layer.cornerRadius = statusView.frame.width / 10
        
        statusView.layer.shadowRadius = statusView.layer.cornerRadius
        statusView.layer.shadowOffset = CGSize(width: 0, height: statusView.frame.height / 20)
        statusView.layer.shadowOpacity = 0.5
        
        // Animate statusView.
        statusView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        let statusViewAnimator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.7) {
            // Reset to default.
            self.statusView.transform = CGAffineTransform.identity
        }
        
        statusViewAnimator.startAnimation()
        
        // Add header label.
        let headerLabel = UILabel()
        
        headerLabel.text = headerText
        
        headerLabel.font = .systemFont(ofSize: 32, weight: .bold)
        headerLabel.textColor = .white
        
        headerLabel.frame.origin = CGPoint(x: statusView.layer.cornerRadius,
                                           y: statusView.layer.cornerRadius)
        headerLabel.sizeToFit()
        
        statusView.addSubview(headerLabel)
        
        // Add ticket image.
        let ticketImageView = UIImageView(image: ticketImage)
        
        if success {
            // Add ticket name label.
            let titleLabel = UILabel()
            
            titleLabel.text = title
            
            titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
            titleLabel.textColor = .white
            
            titleLabel.frame.size = CGSize(width: statusView.frame.width - 2 * statusView.layer.cornerRadius, height: 32)
            titleLabel.frame.origin = CGPoint(x: statusView.layer.cornerRadius,
                                               y: statusView.layer.cornerRadius + headerLabel.frame.height)
            
            titleLabel.adjustsFontSizeToFitWidth = true
            
            statusView.addSubview(titleLabel)
            
            ticketImageView.frame.origin = CGPoint(x: titleLabel.frame.origin.x,
                                                   y: titleLabel.frame.origin.y + titleLabel.frame.height)
        } else {
            ticketImageView.frame.origin = CGPoint(x: headerLabel.frame.origin.x,
                                              y: headerLabel.frame.origin.y + headerLabel.frame.height)
        }
        
        ticketImageView.frame.size.width = statusView.frame.width - statusView.layer.cornerRadius * 2
        ticketImageView.contentMode = .scaleAspectFit
        
        statusView.addSubview(ticketImageView)
        
        // Add description label.
        let descriptionLabel = UILabel()
        
        descriptionLabel.text = descriptionText
        
        descriptionLabel.textColor = .white
        
        descriptionLabel.frame.origin = CGPoint(x: ticketImageView.frame.origin.x,
                                                y: ticketImageView.frame.origin.y + ticketImageView.frame.height)
        descriptionLabel.sizeToFit()
        
        statusView.addSubview(descriptionLabel)
        
        // Add code label.
        let codeLabel = UILabel()
        
        codeLabel.text = code
        
        codeLabel.textColor = UIColor(white: 1.0, alpha: 0.5)
        
        codeLabel.frame.size = CGSize(width: statusView.frame.width - 2 * statusView.layer.cornerRadius,
                                      height: descriptionLabel.frame.height)
        codeLabel.frame.origin = CGPoint(x: descriptionLabel.frame.origin.x,
                                                y: descriptionLabel.frame.origin.y + descriptionLabel.frame.height)
        codeLabel.adjustsFontSizeToFitWidth = true
        
        statusView.addSubview(codeLabel)
        
        view.addSubview(statusView)
        
        // Add dismiss button.
        dismissButton.setImage(dismissImage, for: .normal)
        dismissButton.tintColor = statusColor
        
        dismissButton.frame.size = CGSize(width: 64, height: 64)
        dismissButton.frame.origin = CGPoint(x: view.frame.width / 2 - dismissButton.frame.width / 2,
                                             y: (statusView.frame.origin.y + statusView.frame.height + view.frame.height) / 2 - dismissButton.frame.height / 2)
        
        dismissButton.layer.shadowRadius = statusView.layer.shadowRadius
        dismissButton.layer.shadowOffset = statusView.layer.shadowOffset
        dismissButton.layer.shadowOpacity = statusView.layer.shadowOpacity
        
        dismissButton.addTarget(self, action: #selector(statusDismiss), for: .touchUpInside)
        
        // Animate dismissButton.
        dismissButton.transform = CGAffineTransform(translationX: 0,
                                                    y: view.frame.height - dismissButton.frame.origin.y)
        
        let dismissButtonAnimator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.4) {
            // Reset to default.
            self.dismissButton.transform = CGAffineTransform(translationX: 0,
                                                             y: -self.view.frame.height + self.dismissButton.frame.origin.y)
        }
        
        dismissButtonAnimator.startAnimation()
        
        view.addSubview(dismissButton)
    }
    
    @objc func ticketManager() {
        let navigationController = UINavigationController(rootViewController: TableViewController())
        present(navigationController, animated: true, completion: nil)
        
    }
    
    func saveTicket(code: String) {
        // Append code to file.
        do {
            let fileHandle = try FileHandle(forWritingTo: fileURL!)
            fileHandle.seekToEndOfFile()
            fileHandle.write("\(code)\n".data(using: .utf8)!)
            fileHandle.closeFile()
        } catch {
            print("Could not write to file.")
        }
    }
    
    @objc func statusDismiss() {
        // Remove additional views.
        blurEffectView.removeFromSuperview()
        statusView.removeFromSuperview()
        dismissButton.removeFromSuperview()
        
        // Remove all subviews of statusView.
        for view in self.statusView.subviews {
            view.removeFromSuperview()
        }
    }

    func readJson(url: URL) throws -> [String: Any] {
        // Read JSON data from URL.
        let data = try Data(contentsOf: url)
        // Create dictionary of JSON data.
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        return json
    }

}

