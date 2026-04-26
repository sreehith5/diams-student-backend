import SwiftUI
import AVFoundation

// MARK: - QR Scanner VC

class QRScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    private var session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        let box = UIView(frame: CGRect(x: view.bounds.midX - 120, y: view.bounds.midY - 120, width: 240, height: 240))
        box.layer.borderColor = UIColor.white.cgColor
        box.layer.borderWidth = 2
        box.layer.cornerRadius = 12
        view.addSubview(box)

        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func restart() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let obj = objects.first as? AVMetadataMachineReadableCodeObject,
           let value = obj.stringValue {
            session.stopRunning()
            onScanned?(value)
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    var onScanned: (String) -> Void
    @Binding var vcRef: QRScannerVC?

    func makeUIViewController(context: Context) -> QRScannerVC {
        let vc = QRScannerVC()
        vc.onScanned = onScanned
        DispatchQueue.main.async { vcRef = vc }
        return vc
    }
    func updateUIViewController(_ uiViewController: QRScannerVC, context: Context) {}
}

// MARK: - Student QR Scan View

struct StudentQRScanView: View {
    var onSuccess: () -> Void
    var classId: String = ""

    @State private var phase: Phase = .scanning
    @State private var errorMessage = ""
    @State private var isValidating = false
    @State private var vcRef: QRScannerVC? = nil

    enum Phase { case scanning, validating, failed }

    var body: some View {
        ZStack {
            switch phase {
            case .scanning, .validating:
                QRScannerView(onScanned: handleScanned, vcRef: $vcRef)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    if phase == .validating {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Validating…").foregroundColor(.white).font(.subheadline)
                        }
                        .padding(12).background(Color.black.opacity(0.6)).cornerRadius(10)
                    } else {
                        Text("Point camera at QR code")
                            .font(.subheadline).foregroundColor(.white)
                            .padding(10).background(Color.black.opacity(0.5)).cornerRadius(8)
                    }
                    Spacer().frame(height: 60)
                }

            case .failed:
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 72)).foregroundColor(.red)
                    Text("QR Validation Failed").font(.title2).bold()
                    Text(errorMessage).font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button(action: retry) {
                        Text("Retry").font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(red: 0.102, green: 0.451, blue: 0.910)).cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
                .background(Color.gray.opacity(0.07).ignoresSafeArea())
            }
        }
        .navigationTitle("Scan QR")
    }

    private func handleScanned(_ value: String) {
        phase = .validating
        Task {
            struct ValidateResp: Decodable { let valid: Bool? }
            // QR encodes "class_id|hash" — parse both
            let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
            let resolvedClassId = parts.count == 2 ? parts[0] : (classId.isEmpty ? "LH-1" : classId)
            let hash            = parts.count == 2 ? parts[1] : value
            let body: [String: Any] = [
                "class_id":  resolvedClassId,
                "hash":      hash,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let resp: ValidateResp = try? await APIClient.post("/api/qr/validate", body: body),
               resp.valid == true {
                onSuccess()
            } else {
                errorMessage = "QR code is invalid or expired."
                phase = .failed
            }
        }
    }

    private func retry() {
        errorMessage = ""
        phase = .scanning
        vcRef?.restart()
    }
}
