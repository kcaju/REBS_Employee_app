import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_client.dart';
import '../../core/services/location_service.dart';
import '../../server/embedded_mock_server.dart';
import '../attendance/presentation/attendance_bloc.dart';

class DevSettingsDrawer extends StatefulWidget {
  final VoidCallback onSettingsChanged;

  const DevSettingsDrawer({super.key, required this.onSettingsChanged});

  @override
  State<DevSettingsDrawer> createState() => _DevSettingsDrawerState();
}

class _DevSettingsDrawerState extends State<DevSettingsDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.indigo, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Reviewer Controls',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),

            // 1. Geofence Location Simulation
            Text(
              'LOCATION SIMULATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate Location'),
              subtitle: Text(LocationService.simulateLocation
                  ? 'Simulated coordinates active'
                  : 'Simulation is OFF'),
              value: LocationService.simulateLocation,
              onChanged: (val) {
                setState(() => LocationService.simulateLocation = val);
                widget.onSettingsChanged();
              },
            ),
            if (LocationService.simulateLocation) ...[
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inside Office (<= 200m)'),
                subtitle: const Text('Lat: 12.9716, Lng: 77.5946 (0m away)'),
                value: true,
                groupValue: LocationService.simulateInsideOffice,
                onChanged: (val) {
                  setState(() => LocationService.simulateInsideOffice = val!);
                  widget.onSettingsChanged();
                },
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Outside Office (> 200m)'),
                subtitle: const Text('Simulates 1.6 km away (Violation test)'),
                value: false,
                groupValue: LocationService.simulateInsideOffice,
                onChanged: (val) {
                  setState(() => LocationService.simulateInsideOffice = val!);
                  widget.onSettingsChanged();
                },
              ),
            ],

            const Divider(height: 24),

            // 2. Mock API Scenarios
            Text(
              'SERVER MOCK SCENARIOS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: ApiConfig.activeScenario,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Active Scenario',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'normal',
                  child: Text('Normal (200 / 201 OK)', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'slow',
                  child: Text('Slow Response / Timeout', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'error',
                  child: Text('500 Server Error', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'conflict',
                  child: Text('409 Duplicate Conflict', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'leave_reject',
                  child: Text('422 Leave Reject', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => ApiConfig.activeScenario = val);
                  widget.onSettingsChanged();
                }
              },
            ),

            const Divider(height: 24),

            // 3. In-App Backend Status
            Text(
              'BACKEND STATUS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'In-App Mock Server Active',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Running on internal loopback (127.0.0.1:${EmbeddedMockServer.instance.port})',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // 4. Testing & Session Reset
            Text(
              'TESTING & SESSION RESET',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text("Reset Today's Session"),
              onPressed: () async {
                await context.read<AttendanceCubit>().resetTodaySession();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: const Text(
                'Tip for Reviewers:\n• The app runs 100% standalone using its built-in HTTP server.\n• Use "Server Mock Scenarios" above to test error and conflict handling.\n• Use "Reset Today\'s Session" to test Check-In / Check-Out again.',
                style: TextStyle(fontSize: 12, color: Colors.indigo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
