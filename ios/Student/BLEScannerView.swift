import SwiftUI
import CoreLocation
import Combine

// MARK: - iBeacon Scanner using CoreLocation
class BLEScanner: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let beaconUUID = UUID(uuidString: "49495448-2d41-5454-454e-44414e434520")!
    var classId: String = ""
    var expectedMajor: String? = nil  // fetched from our backend before scan

    @Published var status: BLEScanStatus = .idle
    @Published var result: BLEResult? = nil
    @Published var scanCountdown: Int = 3
    @Published var rawResponse: String? = nil
    @Published var rawRequest: String? = nil

    private var locationManager = CLLocationManager()
    private var allBeacons: [CLBeacon] = []
    private var countdownTimer: Timer? = nil

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    func scan() {
        allBeacons = []
        result = nil
        rawResponse = nil
        rawRequest = nil
        scanCountdown = 3
        status = .scanning

        let constraint = CLBeaconIdentityConstraint(uuid: beaconUUID)
        locationManager.startRangingBeacons(satisfying: constraint)

        var tick = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            tick -= 1
            self?.scanCountdown = tick
            if tick <= 0 {
                t.invalidate()
                self?.finish()
            }
        }
    }

    func stop() {
        let constraint = CLBeaconIdentityConstraint(uuid: beaconUUID)
        locationManager.stopRangingBeacons(satisfying: constraint)
        countdownTimer?.invalidate()
    }

    private func finish() {
        let constraint = CLBeaconIdentityConstraint(uuid: beaconUUID)
        locationManager.stopRangingBeacons(satisfying: constraint)

        // Filter by expected major if we have one, then pick top 4 by RSSI
        var filtered = allBeacons
        if let major = expectedMajor {
            let majorFiltered = allBeacons.filter { String($0.major.intValue) == major }
            if !majorFiltered.isEmpty { filtered = majorFiltered }
        }

        guard !filtered.isEmpty else {
            rawResponse = "No beacons detected"
            status = .notFound
            return
        }

        // Send ALL readings — backend groups by minor and computes median RSSI
        let beaconPayload = filtered.map { b -> [String: Any] in
            ["major": String(b.major.intValue), "minor": String(b.minor.intValue), "rssi": b.rssi]
        }
        let deduped = beaconPayload // naming kept for downstream reference
        status = .validating

        Task {
            let beaconPayload = deduped
            let body: [String: Any] = ["class_id": classId, "beacons": beaconPayload]
            do {
                if let reqData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
                   let reqString = String(data: reqData, encoding: .utf8) {
                    await MainActor.run { rawRequest = reqString }
                }
                let rawData = try await APIClient.postRaw("/api/ble/validate", body: body)
                let rawString = String(data: rawData, encoding: .utf8) ?? "unreadable"
                await MainActor.run { rawResponse = rawString }

                let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: rawData)
                let isValid = decoded["valid"]?.value as? Bool ?? false

                if isValid {
                    if let best = deduped.max(by: { ($0["rssi"] as? Int ?? -999) < ($1["rssi"] as? Int ?? -999) }) {
                        result = BLEResult(
                            minor:    best["minor"] as? Int ?? 0,
                            major:    best["major"] as? Int ?? 0,
                            meanRSSI: Double(best["rssi"] as? Int ?? 0)
                        )
                    }
                    status = .found
                } else {
                    status = .notFound
                }
            } catch {
                await MainActor.run { rawResponse = "Error: \(error.localizedDescription)" }
                status = .notFound
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon],
                         satisfying constraint: CLBeaconIdentityConstraint) {
        allBeacons.append(contentsOf: beacons.filter { $0.proximity != .unknown })
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied { status = .unauthorized }
    }
}

// MARK: - Models
enum BLEScanStatus { case idle, scanning, validating, found, notFound, unauthorized, fetchingMajor }
struct BLEResult { let minor: Int; let major: Int; let meanRSSI: Double }

// MARK: - Student BLE Scan View
struct StudentBLEScanView: View {
    var onSuccess: () -> Void
    var classId: String = ""
    var startedAt: Double = 0
    var durationSeconds: Int = 120

    @StateObject private var scanner = BLEScanner()
    @State private var timeLeft: Int = 120
    @State private var countdownTimer: Timer? = nil
    @State private var majorFetchError: String? = nil

    private let purple = Color(red: 0.416, green: 0.353, blue: 0.804)

    private func computeTimeLeft() -> Int {
        guard startedAt > 0 else { return durationSeconds }
        let elapsed = Int((Date().timeIntervalSince1970 * 1000 - startedAt) / 1000)
        return max(durationSeconds - elapsed, 0)
    }

    // Fetch major for classroom then start scan
    private func fetchMajorAndScan() {
        scanner.status = .fetchingMajor
        Task {
            struct MajorResp: Decodable { let major: String? }
            if let resp: MajorResp = try? await APIClient.get("/api/ble/major/\(classId)"),
               let major = resp.major {
                scanner.expectedMajor = major
            }
            // Proceed even if fetch fails — scan without major filter
            scanner.classId = classId
            scanner.scan()
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 8).frame(width: 110, height: 110)
                Circle()
                    .trim(from: 0, to: CGFloat(timeLeft) / CGFloat(max(durationSeconds, 1)))
                    .stroke(purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 110, height: 110)
                    .animation(.linear(duration: 1), value: timeLeft)
                Text(timeString).font(.title2).bold()
            }
            .padding(.top, 32)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundColor(scanner.status == .scanning ? purple : Color.gray.opacity(0.4))
                .symbolEffect(.pulse, isActive: scanner.status == .scanning)

            Text(statusMessage)
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            if scanner.rawRequest != nil || scanner.rawResponse != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let req = scanner.rawRequest {
                        Text("REQUEST").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        Text(req).font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let res = scanner.rawResponse {
                        Divider()
                        Text("RESPONSE").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        Text(res).font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12).background(Color.black.opacity(0.05)).cornerRadius(10).padding(.horizontal)
            }

            if let r = scanner.result {
                VStack(spacing: 10) {
                    Text("Beacon Detected").font(.headline)
                    Divider()
                    HStack {
                        statLabel("Major", value: "\(r.major)")
                        Spacer()
                        statLabel("Minor", value: "\(r.minor)")
                        Spacer()
                        statLabel("RSSI", value: String(format: "%.0f dBm", r.meanRSSI))
                    }.padding(.horizontal, 8)
                }
                .padding().background(Color.white).cornerRadius(14)
                .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2).padding(.horizontal)
            }

            if scanner.status == .idle || scanner.status == .notFound {
                Button(action: fetchMajorAndScan) {
                    Label("Scan for Beacon", systemImage: "dot.radiowaves.left.and.right")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(purple).cornerRadius(10)
                }
                .padding(.horizontal, 28)
            }

            if scanner.status == .found {
                Button(action: onSuccess) {
                    Text("Continue to Face Verify")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(purple).cornerRadius(10)
                }
                .padding(.horizontal, 28)
            }

            Spacer()
        }
        .navigationTitle("BLE Scan")
        .background(Color.gray.opacity(0.07).ignoresSafeArea())
        .onAppear {
            timeLeft = computeTimeLeft()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeLeft > 0 { timeLeft -= 1 } else { scanner.stop(); countdownTimer?.invalidate() }
            }
        }
        .onDisappear { scanner.stop(); countdownTimer?.invalidate() }
    }

    private var timeString: String { String(format: "%d:%02d", timeLeft / 60, timeLeft % 60) }

    private var statusMessage: String {
        switch scanner.status {
        case .idle:         return "Tap Scan to search for the classroom beacon"
        case .fetchingMajor: return "Fetching beacon info…"
        case .scanning:     return "Scanning... \(scanner.scanCountdown)"
        case .validating:   return "Validating beacon with server..."
        case .found:        return "Beacon validated! ✓"
        case .notFound:     return "Beacon not found or invalid. Try again."
        case .unauthorized: return "Location permission denied. Enable in Settings."
        }
    }

    private func statLabel(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).bold()
        }
    }
}
