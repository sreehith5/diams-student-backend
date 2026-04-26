# DIAMS — Student Backend

Digital Intelligent Attendance Management System  
IIT Hyderabad | SE Course Project

## Overview

Node.js/Express backend that serves the iOS student app. Acts as a proxy/adapter between the iOS app and three external services:

| Service | Owner | Purpose |
|---|---|---|
| Professor Backend | Soham | Source of truth — students, courses, sessions, attendance (MongoDB) |
| Face Recognition | Krishna | Face enrollment and verification |
| BLE Microservice | Abhay | Beacon validation |

Our backend owns: **auth proxying**, **photo enrollment metadata**, **classroom→beacon major mapping**, and **request normalization** between iOS and the external services.

## Architecture

```
iOS App
  │
  ▼
Our Backend (Node.js :3000)
  ├── /api/auth      → Soham's backend  (login)
  ├── /api/student   → Soham's backend  (courses, sessions, attendance)
  │                  → Krishna's backend (face verify/enroll)
  │                  → AWS S3            (profile photos)
  ├── /api/professor → Soham's backend  (courses, sessions, analytics)
  └── /api/ble       → Abhay's backend  (beacon validation)
```

## Stack

- Node.js + Express
- AWS S3 (profile photo storage)
- `node --watch` for development (no nodemon needed)

## Setup

```bash
npm install
```

Create `.env`:
```
PORT=3000
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_BUCKET=...
```

```bash
npm run dev   # starts with --watch (auto-restarts on file changes)
```

## API Reference

See `open-api.yaml` for full OpenAPI 3.0 spec. Quick summary:

| Method | Path | Description |
|---|---|---|
| POST | /api/auth/login | Login (proxies to Soham) |
| GET | /api/student/:id/analytics | Attendance analytics |
| GET | /api/student/:id/sessions | Active sessions |
| POST | /api/student/markAttendance | Mark attendance |
| POST | /api/student/faceVerify | Face verification |
| GET | /api/student/:id/photoStatus | Photo enrollment status |
| POST | /api/student/:id/updatePhoto | Enroll/update face photo |
| GET | /api/professor/:id/courses | Professor's courses |
| GET | /api/professor/:id/activeSession | Active session |
| POST | /api/professor/session/start | Start session |
| POST | /api/professor/session/end/:id | End session |
| GET | /api/professor/session/:id/summary | Session summary |
| GET | /api/professor/:id/course/:code/attendance | Course attendance |
| GET | /api/ble/major/:classroom | Beacon major for classroom |
| POST | /api/ble/validate | Validate BLE beacon |

## Key Design Decisions

**Service account JWT** — Our backend logs into Soham's backend as admin and caches the JWT for 11 hours. Used for all read operations (courses, analytics). Auto-refreshes on expiry.

**JWT forwarding** — For write operations (startSession, markAttendance), the user's own JWT is extracted from the `Authorization` header and forwarded to Soham's backend so his system knows who is acting.

**Classroom→Major mapping** — Stored in `src/data/store.js` since Soham's Beacon model doesn't have a `major` field. Update this when new classrooms are added.

**Photo metadata** — `photoMeta` in `store.js` tracks enrollment timestamps in-memory. Resets on server restart. Will need DB persistence before production.

## File Structure

```
index.js                    — Express app, middleware, route mounting
src/
  config/
    profBackend.js          — Soham's backend URL, JWT cache, profFetch helper
  controllers/
    authController.js       — Login proxy
    studentController.js    — Student endpoints
    professorController.js  — Professor endpoints
    bleController.js        — BLE endpoints
  routes/
    auth.js / student.js / professor.js / ble.js
  data/
    store.js                — photoMeta, classroomMajors
open-api.yaml               — Full API spec
```

## Test Credentials

| Role | Email | Password |
|---|---|---|
| Student | cs22b0001@iith.ac.in | stud123 |
| Professor | arora@iith.ac.in | prof123 |
| Admin | admin@iith.ac.in | adminpass |

## Known Limitations / TODOs

- `photoMeta` is in-memory — resets on server restart, needs DB
- `classroomMajors` is hardcoded — LH-2/7/12 majors are placeholders
- No JWT auth middleware on our own routes (anyone can call our backend)
- Session `durationSeconds` hardcoded to 300s (5 min) — Soham's backend controls actual expiry
- Face verify falls back to mock `{status: "verified"}` if Krishna's service is unreachable
