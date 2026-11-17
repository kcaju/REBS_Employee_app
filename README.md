# REBS HRMS — Offline-Capable Employee Workspace

A production-grade, offline-first Flutter application for the **REBS HRMS Platform**. Employees can view real-time attendance, perform check-in and check-out with 200m geofencing validation, synchronize actions across network outages with guaranteed idempotency, and submit leave applications with comprehensive client-side and server-side validation.

---

## 1. Architecture Overview

This project implements **Clean Architecture** with **Feature-First modularization** and **BLoC / Cubit** for predictable, reactive state management.

```
lib/
├── core/
│   ├── database/             # SQLite AppDatabase via sqflite (ACID & FIFO Queue)
│   ├── network/              # Dio HTTP Client & Interceptors (Idempotency headers)
│   └── services/             # SyncQueueManager (Auto-sync & FIFO) & LocationService (Geofencing)
├── features/
│   ├── dashboard/            # Employee Profile, Status Ticker, Recent 5 Records
│   ├── attendance/           # Geofence validation, Check-in/out logic, SQLite DAO
│   ├── leave/                # Leave form, Overlap/Balance Validator, Leave history
│   └── dev_settings/         # Reviewer Drawer: Mock GPS & Chaos Scenarios
└── server/ (bin/mock_server.dart) # Standalone pure Dart Shelf Mock API Server
```

### Key Engineering Decisions & Justifications

1. **State Management: BLoC / Cubit (`flutter_bloc`)**
   - Clear unidirectional data flow: Event/Action $\rightarrow$ State.
   - Separation of presentation from business rules.
   - 100% testable via `bloc_test` and `mocktail`.

2. **Persistence: SQLite (`sqflite`)**
   - High-performance ACID relational storage.
   - Supports atomic transactions and indexed ordered queries (`ORDER BY timestamp ASC`), which is crucial for preserving FIFO check-in before check-out during synchronization.

3. **Offline Sync & Idempotency Strategy**:
   - Each attendance event generates a unique RFC 4122 v4 UUID (`client_event_id`).
   - Every network request includes `X-Idempotency-Key: <client_event_id>` header.
   - If a connection times out after the server accepted the event, retrying with the same idempotency key allows the server to acknowledge the event without creating duplicate records.
   - Pending events are saved locally in SQLite before any network call (optimistic updates).
   - `SyncQueueManager` monitors connectivity via `connectivity_plus` and drains the pending queue strictly in FIFO order.

4. **Production Server Validation Repeats (Why Device-Side Validation Isn't Enough)**:
   - **GPS Spoofing**: Rooted devices or developer tools can spoof latitude/longitude. A production backend must cross-reference IP geolocation, cell tower IDs, or Wi-Fi BSSID beacons.
   - **Device Time Manipulation**: Users can adjust their device clock to simulate on-time check-ins. The production server must stamp events with its authoritative NTP clock.
   - **Concurrency / Race Conditions**: Concurrent check-in requests must be serialized with database unique constraints `(employee_id, date)`.
   - **Authoritative Balance Ledger**: Leave balance deductions must happen inside atomic database transactions to prevent double-spending.

---

## 2. Setup & Running the Application

### Option A: 100% Standalone In-App Mode (Zero Setup — Recommended for APK Testing)
The application includes an **In-App Embedded Mock Server** running on internal loopback (`http://127.0.0.1:8085`).
- Simply install and open the APK on any phone.
- The app automatically starts its internal `shelf` HTTP server and connects via `dio` over real TCP loopback.
- **Zero commands on your computer are required!**

### Option B: External Mock Server CLI (For Terminal Inspection)
If you prefer running the mock server in a separate terminal to view real-time request logs:
1. Start the server:
   ```bash
   dart run bin/mock_server.dart
   ```
2. The server runs on port `8085`:
   - **Android Emulator**: Uses `http://10.0.2.2:8085`
   - **Desktop / iOS Simulator**: Uses `http://localhost:8085`
   - **Physical Device over Wi-Fi**: Select `Wi-Fi (192.168.1.X:8085)` in the Dev Drawer.
   - **Physical Device over USB**: Run `adb reverse tcp:8085 tcp:8085` and select `localhost:8085`.

### Running from Source
```bash
flutter pub get
flutter run
```

---

## 3. Reviewer Simulation Guide (Dev Drawer)

Open the **Reviewer Controls Drawer** by tapping the **Gear Icon (⚙️)** in the top right of the app bar:

1. **Location Simulation**:
   - **Inside Office (<= 200m)**: Simulates employee at office coordinates (Lat: `12.9716`, Lng: `77.5946`). Allows check-in and check-out.
   - **Outside Office (> 200m)**: Simulates employee 1.6 km away. Triggers geofence violation error message.
   - **Real Device GPS**: Toggle off simulation to use device hardware GPS.
2. **Server Mock Scenarios**:
   - `Normal (200 / 201 OK)`
   - `Slow Response / Timeout`: Simulates network timeouts.
   - `500 Internal Server Error`: Simulates backend failures.
   - `409 Conflict`: Simulates duplicate attendance rejection.
   - `422 Leave Validation Reject`: Simulates server policy rejection.
3. **Dynamic Base URL**: Switch between `10.0.2.2:8080` (Emulator) and `localhost:8080` on the fly.

---

## 4. Demonstration Walkthrough (3–5 Minute Video Checklist)

1. **Dashboard Loading**:
   - Open app $\rightarrow$ Profile header, today's attendance status, leave balances, and 5 most recent records populate.
2. **Online Check-In**:
   - Ensure "Inside Office" is selected in Dev Drawer.
   - Tap **Check In** $\rightarrow$ Status changes to `Checked In`, duration ticker begins counting up, and record is badged as `Synced ✓`.
3. **Offline Attendance Action**:
   - Turn on device **Airplane Mode** (disconnect Wi-Fi/cellular).
   - Tap **Check Out** $\rightarrow$ Status changes to `Checked Out` and displays `Pending Sync ⏳` badge.
4. **App Restart with Pending Action Preserved**:
   - Force kill the application and reopen it.
   - Verify today's status displays `Checked Out` with `Pending Sync ⏳` loaded directly from local SQLite.
5. **Synchronization After Reconnecting**:
   - Turn off Airplane Mode.
   - Tap **Sync Now** (or wait for auto-sync via `connectivity_plus`) $\rightarrow$ Badge updates to `Synced ✓`.
6. **Leave Validation & Submission**:
   - Open Leave Management $\rightarrow$ Tap **Apply Leave**.
   - Test Validation 1: Enter a date range overlapping an existing approved leave $\rightarrow$ Immediate error.
   - Test Validation 2: Enter reason < 10 characters $\rightarrow$ Validation error.
   - Test Validation 3: Enter valid details $\rightarrow$ Tap **Submit Application** $\rightarrow$ Request added to history with `Pending` status.

---

## 5. Automated Tests

Run the full test suite with:
```bash
flutter test
```

### Covered Test Cases:
1. **Check-out without check-in is rejected** (`test/attendance_test.dart`)
2. **Repeated submission or retry does not create duplicate attendance** (`test/attendance_test.dart`)
3. **Pending attendance survives persistence and can be synchronized in order (FIFO)** (`test/attendance_test.dart`)
4. **Overlapping leave dates are rejected** (`test/leave_validator_test.dart`)
5. **Leave date ranges, reason character count, and balance limits** (`test/leave_validator_test.dart`)
6. **Widget test covering 'Pending Sync' badge on Dashboard** (`test/widget_test.dart`)

---

## 6. Assumptions, Trade-offs & Limitations

- **Single Preconfigured Employee**: As requested in Section 1, authentication/login is out of scope; employee `EMP-1049` (Alex Morgan) is preconfigured.
- **Calendar Day Leave Calculations**: As requested in Section 4, weekends and holidays count as calendar days for leave duration.
- **Background Terminated Execution**: In accordance with Section 3, background execution while the app process is terminated was excluded to focus effort on SQLite persistence, FIFO queue handling, and idempotency guarantees.
- **Time Spent**: ~7.5 hours total (Architecture & Mock server: 1h, Database & Models: 1h, Sync Engine: 1.5h, Attendance & Geofencing: 1h, Dashboard & Leave UI: 1.5h, Testing & Documentation: 1.5h).
