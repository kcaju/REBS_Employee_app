# REBS HRMS — Offline-Capable Employee Workspace

A production-grade, offline-first Flutter application for the **REBS HRMS Platform**. Built with **Clean Architecture**, **BLoC / Cubit**, **SQLite (ACID & FIFO Queue)**, and an **In-App Embedded Mock HTTP Server**, this application provides reliable attendance management with geofencing, zero-data-loss offline sync with RFC 4122 v4 idempotency keys, and leave management with client/server validation.

---

## 1. System Architecture & Engineering Highlights

```
lib/
├── core/
│   ├── database/             # SQLite AppDatabase via sqflite (ACID & FIFO Queue)
│   ├── network/              # Dio HTTP Client & Interceptors (Idempotency headers)
│   ├── services/             # SyncQueueManager (Auto-sync & FIFO) & LocationService (Geofencing)
│   ├── theme/                # Dark purple glowing theme & AppBackground container styling
│   └── widgets/              # AppBackground & AppSnackBar (Theme-matched, scenario-aware)
├── features/
│   ├── dashboard/            # Employee Profile, Dynamic Punch Button, Ticker, Stats Box
│   ├── attendance/           # Geofence validation (200m), Check-in/out logic, SQLite DAO
│   ├── leave/                # Leave form, Overlap/Balance Validator, Leave history
│   └── dev_settings/         # Reviewer Drawer: Mock GPS, Network URLs & Chaos Scenarios
└── server/                   # In-App Embedded Shelf Mock HTTP Server (127.0.0.1:8085)
bin/
└── mock_server.dart          # Standalone CLI Shelf Mock Server (optional)
```

### Key Engineering Decisions & Justifications

1. **State Management: BLoC / Cubit (`flutter_bloc`)**
   - Unidirectional data flow (`Action/Event` $\rightarrow$ `Cubit` $\rightarrow$ `State`).
   - Clean separation of business logic from UI widgets.
   - 100% testable using `bloc_test` and `mocktail`.

2. **Persistence: SQLite (`sqflite`)**
   - High-performance ACID-compliant relational storage.
   - Guarantees strict FIFO ordering (`ORDER BY timestamp ASC`), which is crucial for preserving check-in before check-out during offline sync replay.
   - Optimistic local-first writes: actions are persisted immediately with `SyncStatus.pending` before any network transmission.

3. **Offline Sync & Idempotency Strategy**:
   - Each attendance event generates a unique RFC 4122 v4 UUID (`client_event_id`).
   - Every network request includes the `X-Idempotency-Key: <client_event_id>` header.
   - If a connection drops after the server processes an action, retrying with the same idempotency key allows the server to acknowledge the event without creating duplicate records.
   - `SyncQueueManager` monitors connectivity via `connectivity_plus` and drains pending records in sequential FIFO order upon reconnection.

4. **Why Production Backend Validation Repeats Device-Side Validation**:
   - **GPS Spoofing**: Developer tools or rooted devices can fake latitude/longitude. A production backend must cross-reference IP geolocation, cell tower IDs, or Wi-Fi BSSID beacons.
   - **Device Clock Tampering**: Users can change their device clock to simulate on-time check-ins. The production backend stamps events using its authoritative NTP clock.
   - **Race Conditions**: Concurrent check-in requests must be serialized with database unique constraints `(employee_id, date)`.
   - **Authoritative Balance Ledger**: Leave balance deductions must occur inside atomic database transactions to prevent double-spending.

---

## 2. Setup & Running the Application

### Option A: 100% Standalone In-App Mode (Zero Setup — Recommended for APK Testing)
The application includes an **In-App Embedded Mock Server** running on internal loopback (`http://127.0.0.1:8085`).
- Simply install and open the APK on any Android phone.
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

## 3. Comprehensive Feature Catalog

| Feature | Description |
| :--- | :--- |
| **Theme & Background** | Deep purple dark theme (`#150D2A` / `#25164E`) matching `assets/bg.png` with glowing translucent card containers (`#8B5CF6`, `#22D3EE`, `#FB923C`). |
| **Responsive Layout** | Adaptable across all mobile screen widths (320px compact screens to large displays) with zero `RenderFlex` overflow errors. |
| **Geofenced Punch-In/Out** | Concentric glowing circular punch button enforcing a 200-meter radius around configurable office coordinates (`10.8505, 76.2711`) received dynamically from Mock API (`/employee/me`). |
| **Real-Time Duration Ticker** | Automatic live timer running every second while checked in, displaying accumulated working hours. |
| **Today's Status Chip** | Real-time status indicator (`Checked In`, `Checked Out`, `Not Checked In`) with matching iconography and colors. |
| **Attendance Stats Box** | 3-column breakdown showing **Check In** time & sync badge, **Check Out** time & sync badge, and **Working Hrs**. |
| **Recent Attendance List** | Reverse-chronological list of recent punch records with type icons, timestamps, and individual sync badges. |
| **SQLite FIFO Queue** | Offline actions saved locally with `SyncStatus.pending` and synchronized in strict sequential order. |
| **RFC 4122 v4 Idempotency** | Prevents duplicate records on network timeouts and retries using `X-Idempotency-Key`. |
| **Automatic & Manual Sync** | Background auto-sync triggered via `connectivity_plus` on network recovery, plus an AppBar `Sync Now` button with pending count badge. |
| **Leave Balance Overview** | Color-coded circular leave indicators for Paid Leave (Green), Sick Leave (Blue), and Casual Leave (Amber). |
| **Leave Application Form** | Bottom sheet modal with leave type selector, date pickers, auto-calculated duration, and multiline validation error banners. |
| **Strict Leave Validation** | Client- and server-side rules rejecting overlapping dates, past dates, end date < start date, reasons < 10 characters, and insufficient balance. |
| **Leave History Screen** | Clean history view showing seeded records (1 Approved, 1 Rejected) and newly submitted leaves in `Pending` status. |
| **Theme-Matched SnackBars** | Non-truncating floating cards with emerald/crimson borders, short exception descriptions, and active mock scenario tags. |
| **Reviewer Dev Drawer (⚙️)** | Built-in simulator for Mock GPS (Inside/Outside office), Chaos Scenarios (Timeout, 500, 409, 422), and Server URLs. |

---

## 4. Detailed Feature-by-Feature Walkthrough Guide

Follow these step-by-step instructions to experience every feature and validation rule in the application:

### Walkthrough 1: Dashboard & Online Punch-In
1. **Launch the App**: The app opens to the REBS Workspace Dashboard with the dark purple background and glowing card containers.
2. **Review Header**: Notice the employee profile (**EMP-1049**, "Software Engineer", Engineering department) and company date.
3. **Verify Configured Office Coordinates & Mock GPS State**:
   - Tap the **Gear Icon (⚙️)** in the top-right app bar to open the Dev Drawer.
   - Inspect **CONFIGURED OFFICE COORDINATES**:
     ```json
     {
       "office_name": "REBS Office",
       "latitude": 10.8505,
       "longitude": 76.2711,
       "allowed_radius": 200
     }
     ```
     *(Received dynamically from the Mock API `/employee/me` and used in attendance calculations without hardcoding).*
   - Under **LOCATION SIMULATION (DEVELOPMENT MODE)**, ensure **Use Mock Location** is ON and **Inside Office (<= 200m)** is selected (distance: 0m).
   - Swipe left or tap outside to close the drawer.
4. **Perform Punch-In**:
   - Tap the purple glowing **PUNCH IN** button in the attendance box.
   - **Expected Outcome**:
     - A dark floating snackbar with an emerald glowing border confirms: *"Checked in successfully"*.
     - The status chip changes to `Checked In` (green).
     - The button changes from `PUNCH IN` to `PUNCH OUT`.
     - The **Working Hrs** ticker begins incrementing every second (`0h 0m 1s`, `0h 0m 2s`...).
     - The **Check In** stat item displays the current time with a `Synced ✓` badge.
     - A new record appears in the **Recent Attendance** section marked with a `Synced ✓` badge.

---

### Walkthrough 2: Geofencing Rejection (Outside Office)
1. **Simulate Out-of-Bounds Location**:
   - Open the Dev Drawer (⚙️).
   - Under **LOCATION SIMULATION**, select **Outside Office (> 200m)** (simulates ~2.3 km away).
   - Close the drawer.
2. **Attempt Punch Action**:
   - If not checked in, tap **PUNCH IN**; if checked in, tap **PUNCH OUT**.
   - **Expected Outcome**:
     - The action is blocked immediately.
     - A floating snackbar with a crimson glowing border appears:
       > *"You are 2354m away from the office. Check-in is only permitted within 200m."*
     - No records are added to the database.
3. **Restore Location**:
   - Open Dev Drawer (⚙️) $\rightarrow$ Select **Inside Office (<= 200m)**.

---

### Walkthrough 2b: Real Device Hardware GPS Tracking
1. **Toggle Off Mock Location**:
   - Open the Dev Drawer (⚙️).
   - Toggle **Use Mock Location** to **OFF**.
   - Close the drawer.
2. **Device Hardware GPS Evaluation**:
   - The app directly queries real device GPS sensors via `geolocator`.
   - If location permission was not yet granted, the OS permission dialog appears.
   - If your current physical location is outside the 200m radius of REBS Office (`10.8505, 76.2711`), check-in is rejected with your real distance away.
   - To test successful real-world check-in from your current location, you can update the office coordinates in the API or Dev Drawer to match your current GPS coordinates.

---

### Walkthrough 3: Offline Attendance & FIFO SQLite Queue
1. **Simulate Disconnection**:
   - Put your device into **Airplane Mode** (turn off Wi-Fi and Cellular).
2. **Perform Punch-Out While Offline**:
   - Tap the glowing **PUNCH OUT** button.
   - **Expected Outcome**:
     - The action succeeds optimistically: status updates to `Checked Out` (blue).
     - The button transitions to disabled `COMPLETED`.
     - The Working Hrs ticker stops at the final elapsed duration.
     - The **Check Out** stat item displays the time with an amber `Pending Sync ⏳` badge.
     - The AppBar sync icon displays an amber badge count: `1`.
     - The **Recent Attendance** header shows `1 pending`.
     - The new check-out entry shows an amber `Pending Sync ⏳` badge.
3. **Verify Cold-Restart Persistence**:
   - Force-close (kill) the application from your phone's recent apps list.
   - Reopen the app (still in Airplane Mode).
   - **Expected Outcome**:
     - State is completely preserved from SQLite.
     - Today's status remains `Checked Out`, the Working Hrs ticker remains at the completed duration, and all `Pending Sync ⏳` badges remain visible.
4. **Reconnect & Automatic FIFO Sync**:
   - Turn off Airplane Mode (reconnect to Wi-Fi/data).
   - The app's `connectivity_plus` listener immediately detects connectivity and triggers `SyncQueueManager`.
   - Alternatively, tap the **Sync Now** icon in the AppBar.
   - **Expected Outcome**:
     - The sync spinner spins briefly in the AppBar.
     - The pending count badge disappears.
     - The `Pending Sync ⏳` badges on Check-Out and in the Recent Attendance list update to green `Synced ✓`.
     - The server logs confirm the requests were processed in strict FIFO order with idempotency keys.

---

### Walkthrough 4: Server Mock Chaos Scenarios
1. **Duplicate Conflict Scenario (409)**:
   - Open Dev Drawer (⚙️).
   - Under **Server Mock Scenarios**, select **409 Duplicate Conflict**.
   - Close drawer.
   - Tap **Sync Now** in the AppBar.
   - **Expected Outcome**:
     - The snackbar displays the scenario tag and explanation:
       `[SCENARIO: 409 DUPLICATE CONFLICT] Attendance record already exists for this slot.`
2. **Server Error Scenario (500)**:
   - Open Dev Drawer (⚙️) $\rightarrow$ Select **500 Server Error**.
   - Close drawer $\rightarrow$ Tap **Sync Now**.
   - **Expected Outcome**:
     - The snackbar displays:
       `[SCENARIO: 500 SERVER ERROR] Internal server error occurred.`
3. **Leave Validation Reject Scenario (422)**:
   - Open Dev Drawer (⚙️) $\rightarrow$ Select **422 Leave Reject**.
   - Close drawer.
   - Try submitting any leave application.
   - **Expected Outcome**:
     - The snackbar displays:
       `[SCENARIO: 422 LEAVE REJECT] Leave application violates company attendance policy.`
4. **Reset Scenario**:
   - Open Dev Drawer (⚙️) $\rightarrow$ Select **Normal (200 / 201 OK)**.

---

### Walkthrough 5: Leave Management & Client Validations
1. **View Leave Balances**:
   - Scroll down to the **Leave Balances** card on the Dashboard.
   - Notice the 3 color-coded indicators:
     - **Sick Leave**: Available balance (e.g., 8 days) in Blue.
     - **Casual Leave**: Available balance (e.g., 5 days) in Amber.
   - Tap **View History & Apply** (or the Leave tile).
2. **Inspect Initial Leave History**:
   - The Leave History screen opens, displaying exactly 2 initial seeded records:
     - **LR-001**: `Approved` (Casual Leave, 1 day) marked with a green badge.
     - **LR-002**: `Rejected` (Sick Leave, 2 days) marked with a red badge.
3. **Test Validation 1 — Overlapping Dates**:
   - Tap **Apply for Leave** to open the bottom sheet modal.
   - Select **Casual Leave**.
   - Pick dates that overlap with **LR-001** (e.g., Nov 10, 2026).
   - Type a reason: `Taking personal time off`.
   - Tap **Submit Application**.
   - **Expected Outcome**:
     - Submission is blocked.
     - A red validation banner appears:
       > *"Selected dates overlap with an existing approved leave application."*
4. **Test Validation 2 — Reason Too Short (< 10 characters)**:
   - Change the dates to non-overlapping future dates (e.g., Nov 24, 2026 to Nov 25, 2026).
   - Enter reason: `Vacation` (only 8 characters).
   - Tap **Submit Application**.
   - **Expected Outcome**:
     - Submission is blocked.
     - The reason field highlights with a red border:
       > *"Reason must contain at least 10 non-whitespace characters (currently 8/10)."*
5. **Test Validation 3 — Request Exceeding Available Balance**:
   - Select **Casual Leave** (balance: 6 days).
   - Pick a 10-day date range (e.g., Dec 1 to Dec 10).
   - Enter reason: `Annual vacation with family`.
   - Tap **Submit Application**.
   - **Expected Outcome**:
     - Submission is blocked with validation message:
       > *"Requested duration (10 days) exceeds your available Casual Leave balance (6.0 days)."*
6. **Successful Leave Submission**:
   - Pick a valid 2-day date range (e.g., Nov 25, 2026 to Nov 26, 2026).
   - Type reason: `Family function and travel`.
   - Tap **Submit Application**.
   - **Expected Outcome**:
     - The sheet closes smoothly.
     - A dark floating snackbar with an emerald border confirms: *"Leave application submitted successfully (Pending Approval)"*.
     - The new leave request appears at the top of the **Leave History** screen with a `Pending` (amber) badge.
     - The available balance on the dashboard updates accordingly (e.g. Casual balance drops from 8 to 6 days).
7. **Verify Persistence Across App Kill (Cold Restart)**:
   - Force close (swipe away/kill) the application from your phone's recent apps switcher.
   - Reopen the app.
   - **Expected Outcome**:
     - **Leave Balances**: The dashboard card immediately shows the remaining balance (`6 Days` Casual, `5 Days` Sick) loaded from persistent SQLite storage.
     - **Leave History**: Tap **Manage & Apply ➔**; the submitted leave remains at the top with `Pending` status alongside the seeded records.
     - **Balance Cards**: The top balance cards in the Leave History screen also display the remaining balance (`6 Days` and `5 Days`).
     - **Subsequent Validations**: Opening the Apply Leave form correctly limits subsequent requests to the remaining balance (6 days).

---

## 5. Automated Test Suite

The project includes unit, domain, and widget test suites covering all critical business rules, validations, and edge cases.

### Running Tests
```bash
flutter test
```

### Complete Test Coverage Matrix (12/12 Passing)

| # | Test Suite | Test Case Description | Requirement Covered |
| :-: | :--- | :--- | :--- |
| **1** | `leave_validator_test.dart` | Overlapping leave dates with approved leaves are rejected | Requirement 4 (Leave overlap rule) |
| **2** | `leave_validator_test.dart` | Non-overlapping leave dates are accepted | Valid leave submission |
| **3** | `leave_validator_test.dart` | Start date before current company date is rejected | Past date validation |
| **4** | `leave_validator_test.dart` | End date before start date is rejected | Date range order validation |
| **5** | `leave_validator_test.dart` | Reason with less than 10 non-whitespace characters is rejected | Character count validation |
| **6** | `leave_validator_test.dart` | Requested days exceeding available balance is rejected | Leave balance boundary check |
| **7** | `leave_validator_test.dart` | Submitted pending leave reduces available balance in leave repository calculations | Persistent balance deduction rule |
| **8** | `attendance_test.dart` | Check-out without check-in is rejected | Attendance state machine rule |
| **9** | `attendance_test.dart` | Repeated submission or retry does not create duplicate attendance | RFC 4122 v4 Idempotency key |
| **10** | `attendance_test.dart` | Pending attendance survives persistence and syncs in order (FIFO) | SQLite persistence & FIFO order |
| **11** | `attendance_test.dart` | Configurable office coordinates allow check-in within 200m and reject beyond 200m | Configurable office geofence rule |
| **12** | `widget_test.dart` | Dashboard renders Today's status chip, 'Pending Sync' badge, and pending count badge | UI state & offline badge rendering |

---

## 6. Dependencies & Tools

- **Flutter SDK**: `^3.24.0` (Dart `^3.5.0`)
- **State Management**: `flutter_bloc: ^8.1.6`, `bloc: ^8.1.4`
- **Local Database**: `sqflite: ^2.4.1`, `path: ^1.9.1`
- **Networking**: `dio: ^5.7.0`
- **Location & Geofencing**: `geolocator: ^13.0.2`
- **Network Connectivity**: `connectivity_plus: ^6.1.1`
- **In-App Mock Server**: `shelf: ^1.4.2`, `shelf_router: ^1.1.4`
- **Testing**: `flutter_test`, `bloc_test: ^9.1.7`, `mocktail: ^1.0.4`
