import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_client.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
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
      backgroundColor: const Color(0xFF181035),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            Row(
              children: const [
                Icon(Icons.tune_rounded, color: AppTheme.purpleLight, size: 26),
                SizedBox(width: 12),
                Text(
                  'Reviewer Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),

            // 1. Geofence Location Simulation
            const Text(
              'LOCATION SIMULATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: const Color(0xFF24164C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: AppTheme.purplePrimary,
                    title: const Text('Simulate Location', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      LocationService.simulateLocation ? 'Simulated coordinates active' : 'Simulation is OFF',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    value: LocationService.simulateLocation,
                    onChanged: (val) {
                      setState(() => LocationService.simulateLocation = val);
                      widget.onSettingsChanged();
                    },
                  ),
                  if (LocationService.simulateLocation) ...[
                    const Divider(height: 1, color: Colors.white10),
                    RadioListTile<bool>(
                      activeColor: AppTheme.purplePrimary,
                      title: const Text('Inside Office (<= 200m)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Ernakulam (Lat: 9.9816, Lng: 76.2999)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      value: true,
                      groupValue: LocationService.simulateInsideOffice,
                      onChanged: (val) {
                        setState(() => LocationService.simulateInsideOffice = val!);
                        widget.onSettingsChanged();
                      },
                    ),
                    RadioListTile<bool>(
                      activeColor: AppTheme.purplePrimary,
                      title: const Text('Outside Office (> 200m)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Simulates 1.6 km away (Violation test)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      value: false,
                      groupValue: LocationService.simulateInsideOffice,
                      onChanged: (val) {
                        setState(() => LocationService.simulateInsideOffice = val!);
                        widget.onSettingsChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 24, color: Colors.white12),

            // 2. Mock API Scenarios
            const Text(
              'SERVER MOCK SCENARIOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF24164C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: const Color(0xFF24164C),
                value: ApiConfig.activeScenario,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Active Scenario',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'normal',
                    child: Text('Normal (200 / 201 OK)', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'slow',
                    child: Text('Slow Response / Timeout', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'error',
                    child: Text('500 Server Error', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'conflict',
                    child: Text('409 Duplicate Conflict', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'leave_reject',
                    child: Text('422 Leave Reject', style: TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => ApiConfig.activeScenario = val);
                    widget.onSettingsChanged();
                  }
                },
              ),
            ),

            const Divider(height: 24, color: Colors.white12),

            // 3. In-App Backend Status
            const Text(
              'BACKEND STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x2210B981),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4410B981)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'In-App Mock Server Active',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF34D399)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Running on internal loopback (127.0.0.1:${EmbeddedMockServer.instance.port})',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24, color: Colors.white12),

            // 4. Testing & Session Reset
            const Text(
              'TESTING & SESSION RESET',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                side: const BorderSide(color: Colors.orangeAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text("Reset Today's Session"),
              onPressed: () async {
                await context.read<AttendanceCubit>().resetTodaySession();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x228B5CF6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x448B5CF6)),
              ),
              child: const Text(
                'Tip for Reviewers:\n• Built-in mock HTTP server runs 100% standalone.\n• Change "Server Mock Scenarios" to test error/conflict handling.\n• Use "Reset Today\'s Session" to test Check-In / Check-Out again.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
