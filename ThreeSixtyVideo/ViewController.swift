//
//  ViewController.swift
//  ThreeSixtyVideo
//
//  Created by AK on 8/6/24.
//

import UIKit
import AVFoundation
import Photos
class ViewController: UIViewController {
    
    private let cameraManager = CameraManager()
        private var previewLayerFront: AVCaptureVideoPreviewLayer?
        private var previewLayerBack: AVCaptureVideoPreviewLayer?
        private let recordButton = UIButton(type: .system)
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            
            setupPreviewLayers()
            setupUI()
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            cameraManager.captureSession?.startRunning()
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            cameraManager.captureSession?.stopRunning()
        }
        
        private func setupUI() {
            view.backgroundColor = .black
            
            recordButton.setTitle("Start Recording", for: .normal)
            recordButton.backgroundColor = .red
            recordButton.setTitleColor(.white, for: .normal)
            recordButton.layer.cornerRadius = 10
            recordButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
            
            view.addSubview(recordButton)
            recordButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                recordButton.widthAnchor.constraint(equalToConstant: 160),
                recordButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
        
        private func setupPreviewLayers() {
            guard let session = cameraManager.captureSession else { return }
            
            previewLayerFront = AVCaptureVideoPreviewLayer(session: session)
            previewLayerBack = AVCaptureVideoPreviewLayer(session: session)
            
            if let previewLayerFront = previewLayerFront, let previewLayerBack = previewLayerBack {
                previewLayerFront.videoGravity = .resizeAspectFill
                previewLayerBack.videoGravity = .resizeAspectFill
                
                let screenSize = UIScreen.main.bounds.size
                let screenWidth = screenSize.width
                let screenHeight = screenSize.height
                
                previewLayerFront.frame = CGRect(x: 0, y: 0, width: screenWidth / 2, height: screenHeight)
                previewLayerBack.frame = CGRect(x: screenWidth / 2, y: 0, width: screenWidth / 2, height: screenHeight)
                
                view.layer.addSublayer(previewLayerFront)
                view.layer.addSublayer(previewLayerBack)
            }
        }
        
        @objc private func toggleRecording() {
            if cameraManager.isRecording {
                cameraManager.stopRecording()
                recordButton.setTitle("Start Recording", for: .normal)
                recordButton.backgroundColor = .red
            } else {
                cameraManager.startRecording()
                recordButton.setTitle("Stop Recording", for: .normal)
                recordButton.backgroundColor = .green
            }
        }
}
