import SwiftUI
import AVFoundation

// Simple front camera preview with manual capture
class SimpleCameraVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "simple.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var latestBuffer: CVPixelBuffer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }
        if let conn = output.connection(with: .video) {
            conn.videoOrientation = .portrait
            conn.isVideoMirrored = true
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        latestBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    }

    func captureCurrentFrame() -> String? {
        guard let pb = latestBuffer else { return nil }
        let ci = CIImage(cvPixelBuffer: pb)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent),
              let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.8) else { return nil }
        return jpeg.base64EncodedString()
    }
}

struct SimpleCameraView: UIViewControllerRepresentable {
    @Binding var vcRef: SimpleCameraVC?

    func makeUIViewController(context: Context) -> SimpleCameraVC {
        let vc = SimpleCameraVC()
        DispatchQueue.main.async { vcRef = vc }
        return vc
    }
    func updateUIViewController(_ uiViewController: SimpleCameraVC, context: Context) {}
}
