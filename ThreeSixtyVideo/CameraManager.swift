//
//  CameraManager.swift
//  ThreeSixtyVideo
//
//  Created by AK on 8/6/24.
//

import AVFoundation
import UIKit
import Photos

class CameraManager: NSObject, ObservableObject {
    var captureSession: AVCaptureMultiCamSession?
    private var videoOutputFront: AVCaptureVideoDataOutput?
    private var videoOutputBack: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var frontCameraConnection: AVCaptureConnection?
    private var backCameraConnection: AVCaptureConnection?
    private var audioConnection: AVCaptureConnection?
    private var assetWriter: AVAssetWriter?
    private var pixelBufferAdaptorFront: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelBufferAdaptorBack: AVAssetWriterInputPixelBufferAdaptor?
    private var assetWriterInputAudio: AVAssetWriterInput?
    private var frontBufferQueue = [CMSampleBuffer]()
    private var backBufferQueue = [CMSampleBuffer]()

    @Published var isRecording = false

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        captureSession = AVCaptureMultiCamSession()

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Cameras not available")
            return
        }

        do {
            let frontInput = try AVCaptureDeviceInput(device: frontCamera)
            let backInput = try AVCaptureDeviceInput(device: backCamera)

            if captureSession?.canAddInput(frontInput) == true {
                captureSession?.addInput(frontInput)
            }

            if captureSession?.canAddInput(backInput) == true {
                captureSession?.addInput(backInput)
            }

            videoOutputFront = AVCaptureVideoDataOutput()
            videoOutputBack = AVCaptureVideoDataOutput()
            audioOutput = AVCaptureAudioDataOutput()

            videoOutputFront?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueueFront"))
            videoOutputBack?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueueBack"))
            audioOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))

            if captureSession?.canAddOutput(videoOutputFront!) == true {
                captureSession?.addOutput(videoOutputFront!)
                frontCameraConnection = videoOutputFront?.connection(with: .video)
                frontCameraConnection?.videoRotationAngle = .zero
            }

            if captureSession?.canAddOutput(videoOutputBack!) == true {
                captureSession?.addOutput(videoOutputBack!)
                backCameraConnection = videoOutputBack?.connection(with: .video)
                backCameraConnection?.videoRotationAngle = .zero
            }

            if captureSession?.canAddOutput(audioOutput!) == true {
                captureSession?.addOutput(audioOutput!)
                audioConnection = audioOutput?.connection(with: .audio)
            }
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }

    func startRecording() {
        guard !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(randomString(length: 8)).mov")

        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

            let videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080
            ] as [String: Any]

            let videoInputFront = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            let videoInputBack = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            pixelBufferAdaptorFront = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInputFront, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB])
            pixelBufferAdaptorBack = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInputBack, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB])

            videoInputFront.expectsMediaDataInRealTime = true
            videoInputBack.expectsMediaDataInRealTime = true

            //if let videoInputFront = videoInputFront, let videoInputBack = videoInputBack {
                if assetWriter?.canAdd(videoInputFront) == true {
                    assetWriter?.add(videoInputFront)
                }

                if assetWriter?.canAdd(videoInputBack) == true {
                    assetWriter?.add(videoInputBack)
                }
            //}

            let audioSettings = audioOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: Any]
            assetWriterInputAudio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)

            if let inputAudio = assetWriterInputAudio {
                inputAudio.expectsMediaDataInRealTime = true

                if assetWriter?.canAdd(inputAudio) == true {
                    assetWriter?.add(inputAudio)
                }
            }

            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            isRecording = true
        } catch {
            print("Error starting recording: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        pixelBufferAdaptorFront?.assetWriterInput.markAsFinished()
        pixelBufferAdaptorBack?.assetWriterInput.markAsFinished()
        assetWriterInputAudio?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            if let outputURL = self.assetWriter?.outputURL {
                print("Video file URL: \(outputURL)")
                self.saveVideoToPhotos(outputURL)
            } else {
                print("Error: assetWriter outputURL is nil")
            }
        }
    }

    private func saveVideoToPhotos(_ outputURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Photos access not authorized")
                return
            }

            // Check if the file exists
            if !FileManager.default.fileExists(atPath: outputURL.path) {
                print("File does not exist at path: \(outputURL.path)")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                creationRequest.addResource(with: .video, fileURL: outputURL, options: options)
            }) { success, error in
                if success {
                    print("Video saved to Photos successfully.")
                } else if let error = error {
                    print("Error saving video to Photos: \(error.localizedDescription)")
                } else {
                    print("Unknown error saving video to Photos.")
                }
            }
        }
    }

}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }

        if connection == frontCameraConnection {
            frontBufferQueue.append(sampleBuffer)
            print("Front buffer appended")
        } else if connection == backCameraConnection {
            backBufferQueue.append(sampleBuffer)
            print("Back buffer appended")
        } else if connection == audioConnection {
            if assetWriterInputAudio?.isReadyForMoreMediaData == true {
                assetWriterInputAudio?.append(sampleBuffer)
                print("Audio buffer appended")
            }
        }

        synchronizeAndAppendBuffers()
    }

    private func synchronizeAndAppendBuffers() {
        let tolerance = CMTime(seconds: 0.05, preferredTimescale: 600)
        
        while !frontBufferQueue.isEmpty && !backBufferQueue.isEmpty {
            let frontBuffer = frontBufferQueue.first!
            let backBuffer = backBufferQueue.first!
            
            let frontTime = CMSampleBufferGetPresentationTimeStamp(frontBuffer)
            let backTime = CMSampleBufferGetPresentationTimeStamp(backBuffer)
            
            let timeDifference = CMTimeSubtract(frontTime, backTime)
            let absoluteDifference = CMTimeCompare(timeDifference, CMTime.zero) < 0 ? CMTimeMultiplyByFloat64(timeDifference, multiplier: -1.0) : timeDifference
            
            if CMTimeCompare(absoluteDifference, tolerance) <= 0 {
                frontBufferQueue.removeFirst()
                backBufferQueue.removeFirst()
                
                if let pixelBufferAdaptorFront = pixelBufferAdaptorFront, pixelBufferAdaptorFront.assetWriterInput.isReadyForMoreMediaData {
                    let pixelBuffer = CMSampleBufferGetImageBuffer(frontBuffer)!
                    pixelBufferAdaptorFront.append(pixelBuffer, withPresentationTime: frontTime)
                    print("Front buffer appended to asset writer at time: \(frontTime)")
                }
                
                if let pixelBufferAdaptorBack = pixelBufferAdaptorBack, pixelBufferAdaptorBack.assetWriterInput.isReadyForMoreMediaData {
                    let pixelBuffer = CMSampleBufferGetImageBuffer(backBuffer)!
                    pixelBufferAdaptorBack.append(pixelBuffer, withPresentationTime: backTime)
                    print("Back buffer appended to asset writer at time: \(backTime)")
                }
            } else {
                if CMTimeCompare(frontTime, backTime) < 0 {
                    frontBufferQueue.removeFirst()
                    frontBufferQueue.append(frontBuffer)
                } else {
                    backBufferQueue.removeFirst()
                    backBufferQueue.append(backBuffer)
                }
                break
            }
        }
    }
}
