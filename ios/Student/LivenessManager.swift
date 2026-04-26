import AVFoundation
import UIKit
import Vision

enum LivenessState {
    case scanning
    case capturing
    case completed
    case failed
}

protocol LivenessDelegate: AnyObject {
    func onPromptChanged(_ text: String)
    func onProgressChanged(_ count: Int)
    func onSuccess(base64Frames: [String])
    func onFailure(reason: String)
}

class LivenessManager: NSObject {

    weak var delegate: LivenessDelegate?

    private(set) var state: LivenessState = .scanning
    private var capturedFrames: [String] = []
    private var capturedBoxes: [CGRect] = []   // track face positions across captures

    private var lastCaptureTime: TimeInterval = 0
    private let captureInterval: TimeInterval = 0.8  // longer gap forces more movement opportunity

    func startSession() {
        state = .scanning
        capturedFrames = []
        capturedBoxes = []
        lastCaptureTime = 0
        delegate?.onPromptChanged("Move closer and look straight at the camera")
        delegate?.onProgressChanged(0)
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard state == .scanning || state == .capturing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] req, _ in
            guard let self else { return }
            let faces = req.results as? [VNFaceObservation] ?? []
            self.evaluate(faces: faces, buffer: sampleBuffer)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        try? handler.perform([request])
    }

    private func evaluate(faces: [VNFaceObservation], buffer: CMSampleBuffer) {
        guard faces.count == 1, let face = faces.first else { return }

        let box = face.boundingBox
        let centreX = box.midX
        let isCentred = centreX > 0.25 && centreX < 0.75
        // Require face to be large — forces user close, makes photo spoofing harder
        let isCloseEnough = box.width > 0.35

        switch state {
        case .scanning:
            if isCentred && isCloseEnough {
                state = .capturing
                delegate?.onPromptChanged("Hold still…")
                captureFrame(from: buffer, box: box)
            } else if !isCloseEnough {
                delegate?.onPromptChanged("Move closer to the camera")
            }

        case .capturing:
            guard let firstBox = capturedBoxes.first else { return }

            // Anti-spoofing: fail if face moves too much (swap/leave)
            let drift = abs(box.midX - firstBox.midX) + abs(box.midY - firstBox.midY)
            guard drift < 0.20 else {
                state = .failed
                delegate?.onFailure(reason: "Face lost. Please restart.")
                return
            }

            captureFrame(from: buffer, box: box)

        default:
            break
        }
    }

    private func captureFrame(from buffer: CMSampleBuffer, box: CGRect) {
        guard capturedFrames.count < 3 else { return }

        let now = Date().timeIntervalSince1970
        guard now - lastCaptureTime >= captureInterval else { return }
        lastCaptureTime = now

        guard let b64 = bufferToBase64(buffer) else { return }
        capturedFrames.append(b64)
        capturedBoxes.append(box)
        delegate?.onProgressChanged(capturedFrames.count)

        if capturedFrames.count == 3 {
            // Liveness check: require measurable micro-movement across 3 frames
            // A static photo will have near-zero movement; a real face always shifts slightly
            let first = capturedBoxes[0]
            let last  = capturedBoxes[2]
            let totalMovement = abs(last.midX - first.midX) + abs(last.midY - first.midY)
                              + abs(last.width - first.width)

            if totalMovement < 0.003 {
                // Suspiciously static — likely a photo
                state = .failed
                delegate?.onFailure(reason: "Liveness check failed. Please try again with your real face.")
                return
            }

            state = .completed
            delegate?.onPromptChanged("Liveness verified!")
            delegate?.onSuccess(base64Frames: capturedFrames)
        }
    }

    private func bufferToBase64(_ buffer: CMSampleBuffer) -> String? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.6) else { return nil }
        return jpeg.base64EncodedString()
    }
}
