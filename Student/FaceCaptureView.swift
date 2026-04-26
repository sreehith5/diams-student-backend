import SwiftUI
import AVFoundation

// MARK: - Camera VC backed by LivenessManager

class LivenessCameraVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, LivenessDelegate {

    let manager = LivenessManager()
    var onSuccess: (([String]) -> Void)?
    var onFailure: ((String) -> Void)?
    var onPrompt: ((String) -> Void)?
    var onProgress: ((Int) -> Void)?

    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "liveness.capture")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        manager.delegate = self

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
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
        manager.startSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func restart() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }
        manager.startSession()
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        manager.processFrame(sampleBuffer)
    }

    // MARK: - LivenessDelegate
    func onPromptChanged(_ text: String) {
        DispatchQueue.main.async { self.onPrompt?(text) }
    }
    func onProgressChanged(_ count: Int) {
        DispatchQueue.main.async { self.onProgress?(count) }
    }
    func onSuccess(base64Frames: [String]) {
        DispatchQueue.main.async {
            self.session.stopRunning()
            self.onSuccess?(base64Frames)
        }
    }
    func onFailure(reason: String) {
        DispatchQueue.main.async {
            self.session.stopRunning()
            self.onFailure?(reason)
        }
    }
}

// MARK: - SwiftUI wrapper for the camera VC

struct LivenessCameraView: UIViewControllerRepresentable {
    @Binding var vcRef: LivenessCameraVC?
    var onSuccess: ([String]) -> Void
    var onFailure: (String) -> Void
    var onPrompt: (String) -> Void
    var onProgress: (Int) -> Void

    func makeUIViewController(context: Context) -> LivenessCameraVC {
        let vc = LivenessCameraVC()
        vc.onSuccess  = onSuccess
        vc.onFailure  = onFailure
        vc.onPrompt   = onPrompt
        vc.onProgress = onProgress
        DispatchQueue.main.async { vcRef = vc }
        return vc
    }
    func updateUIViewController(_ uiViewController: LivenessCameraVC, context: Context) {}
}

// MARK: - Face Verify Screen

struct StudentFaceVerifyView: View {
    var onSuccess: () -> Void
    var username: String

    @State private var phase: Phase = .liveness
    @State private var prompt = "Look straight at the camera"
    @State private var progress = 0
    @State private var failureReason = ""
    @State private var isSubmitting = false
    @State private var serverResponse = ""
    @State private var vcRef: LivenessCameraVC? = nil

    enum Phase { case liveness, submitting, success, failure }

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .liveness:
                livenessView

            case .submitting:
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView("Verifying face…").font(.headline)
                    Spacer()
                }

            case .success:
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 0.204, green: 0.659, blue: 0.325))
                    Text("Attendance Marked!")
                        .font(.title).bold()
                    Text("You're all set for this class.")
                        .font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failure:
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: failureReason.contains("Face lost") ? "face.dashed" : "xmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    Text(failureReason.contains("Face lost") ? "Liveness Failed" : "Verification Failed")
                        .font(.title).bold()
                    Text(failureReason.isEmpty ? "Face not recognised." : failureReason)
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button(action: restart) {
                        Text("Restart")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(red: 0.102, green: 0.451, blue: 0.910))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .navigationTitle("Face Verify")
    }

    // MARK: - Liveness camera view with prompt overlay
    private var livenessView: some View {
        ZStack(alignment: .bottom) {
            LivenessCameraView(
                vcRef: $vcRef,
                onSuccess: { frames in
                    phase = .submitting
                    Task { await submitFrames(frames) }
                },
                onFailure: { reason in
                    failureReason = reason
                    phase = .failure
                },
                onPrompt: { prompt = $0 },
                onProgress: { progress = $0 }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Prompt banner
                Text(prompt)
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.top, 16)

                Spacer()

                // Progress dots
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < progress
                                  ? Color(red: 0.204, green: 0.659, blue: 0.325)
                                  : Color.white.opacity(0.5))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func restart() {
        prompt = "Look straight at the camera"
        progress = 0
        failureReason = ""
        serverResponse = ""
        phase = .liveness
        vcRef?.restart()
    }

    private func submitFrames(_ frames: [String]) async {
        do {
            struct FaceVerifyRequest: Encodable { let userId: String; let frames: [String]; let challenges: [String] }
            struct FaceVerifyResponse: Decodable { let status: String? }
            let body = FaceVerifyRequest(userId: username, frames: frames, challenges: [])
            guard let url = URL(string: backendBase + "/api/student/faceVerify") else { throw URLError(.badURL) }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: req)
            let response = try JSONDecoder().decode(FaceVerifyResponse.self, from: data)
            if response.status == "verified" {
                phase = .success
                onSuccess()
            } else {
                failureReason = "Face not recognised by server."
                phase = .failure
            }
        } catch {
            failureReason = "Error: \(error.localizedDescription)"
            phase = .failure
        }
    }
}
