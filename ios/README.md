# DIAMS — iOS App

Digital Intelligent Attendance Management System  
IIT Hyderabad | SE Course Project

## Overview

SwiftUI iOS app for students and professors. Students mark attendance via BLE + face verification. Professors start/manage sessions and view analytics.

## Architecture

```
iOS App
  │
  ├── Student flow  → Our Backend (:3000)
  └── Professor flow → Our Backend (:3000) → Soham's Backend
```

The app talks exclusively to our student backend. The backend handles all routing to external services.

## Setup

1. Open `AttendanceApp.xcodeproj` in Xcode
2. Update `backendBase` in `Shared/APIClient.swift` to your Mac's local IP:
   ```swift
   let backendBase = "http://<YOUR_MAC_IP>:3000"
   ```
   Find your IP: `ipconfig getifaddr en0`
3. Ensure backend is running: `npm run dev` in the Backend folder
4. Build & run on device (BLE requires physical device, not simulator)

## File Structure

```
App/
  AppState.swift          — ObservableObject: user, profileImage, session restore
  ContentView.swift       — Root view, role-based routing, session restore on launch
  AttendanceAppApp.swift  — @main entry point

Auth/
  RoleSelectionView.swift — Pick Student / Professor / Admin
  LoginView.swift         — Email + password login, saves JWT to Keychain

Shared/
  APIClient.swift         — GET/POST helpers, attaches JWT, auto-refresh on 401
  KeychainHelper.swift    — Secure storage for JWT, email, password, role
  MainTabView.swift       — StudentTabView, ProfessorTabView, AdminTabView
                            ProfileSheet, PhotoCaptureSheet

Student/
  DashboardView.swift     — Attendance analytics per course
  ActiveSessionsView.swift — Session polling, MarkAttendanceFlow (BLE→Face)
  BLEScannerView.swift    — CoreLocation iBeacon scanning, major filtering
  FaceCaptureView.swift   — LivenessCameraVC, StudentFaceVerifyView
  LivenessManager.swift   — Apple Vision face detection, 3-frame capture
  QRScannerView.swift     — QR code scanning (not yet integrated)

Professor/
  ProfessorView.swift     — Courses, session management, analytics, BLE/QR/Manual views

Admin/
  AdminView.swift         — Admin dashboard (mirrors professor view)
```

## Key Flows

### Login & Session Persistence
1. User selects role → enters email + password
2. `POST /api/auth/login` → JWT returned
3. JWT + credentials + role saved to **Keychain** (survives app close/restart)
4. On next launch: JWT validity checked → if valid, session restored instantly → if expired, silent re-login with stored credentials

### Student — Mark Attendance (BLE)
1. Active sessions polled every 5s
2. Tap "Mark Attendance" → BLE step
3. `GET /api/ble/major/:classroom` → get expected beacon major
4. Scan iBeacons (UUID: `49495448-2d41-5454-454e-44414e434520`) for 3s
5. Filter by major, pick top 4 RSSI → `POST /api/ble/validate`
6. On success → Face step
7. Apple Vision locks on face, captures 3 frames (0.8s apart), checks micro-movement
8. `POST /api/student/faceVerify` → Krishna's backend
9. On verified → `POST /api/student/markAttendance`

### Professor — Start Session
1. Tap course → ClassDetailView
2. Tap BLE/QR/Manual → `POST /api/professor/session/start`
3. Professor's JWT forwarded to Soham's backend
4. Session timer shown (5 min default)
5. Students see session appear in their Active Sessions within 5s

## Dependencies

- **Apple Vision** (built-in) — face detection for liveness
- **CoreLocation** (built-in) — iBeacon scanning
- **Security** (built-in) — Keychain storage
- No third-party dependencies / CocoaPods / SPM packages

## Test Credentials

| Role | Email | Password |
|---|---|---|
| Student | cs22b0001@iith.ac.in | stud123 |
| Professor | arora@iith.ac.in | prof123 |

## Known Limitations / TODOs

- QR flow not yet integrated with Abhay's backend
- `backendBase` IP must be updated manually when network changes
- BLE requires physical device (no simulator support)
- Liveness detection is client-side only — can be bypassed on jailbroken devices
- LH-2, LH-7, LH-12 beacon majors are placeholder values in backend
- Sessions auto-end outside scheduled lecture times (Soham's cron behavior)
