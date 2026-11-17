import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/location_service.dart';

class DevSettingsDrawer extends StatefulWidget {
  final VoidCallback onSettingsChanged;

  const DevSettingsDrawer({super.key, required this.onSettingsChanged});

  @override
  State<DevSettingsDrawer> createState() => _DevSettingsDrawerState();
}

class _DevSettingsDrawerState extends State<DevSettingsDrawer> {
  final TextEditingController _urlController = TextEditingController(text: ApiConfig.activeBaseUrl);

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

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
                  : 'Using real device GPS'),
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

            // 3. API Host Address
            Text(
              'API BASE URL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. http://10.0.2.2:8080',
                labelText: 'Server URL',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 16, color: Colors.green),
                  label: const Text('In-App Standalone (127.0.0.1)'),
                  onPressed: () {
                    _urlController.text = 'http://127.0.0.1:8085';
                  },
                ),
                ActionChip(
                  label: const Text('USB (localhost:8085)'),
                  onPressed: () {
                    _urlController.text = 'http://localhost:8085';
                  },
                ),
                ActionChip(
                  label: const Text('Wi-Fi (192.168.1.100:8085)'),
                  onPressed: () {
                    _urlController.text = 'http://192.168.1.100:8085';
                  },
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2:8085)'),
                  onPressed: () {
                    _urlController.text = 'http://10.0.2.2:8085';
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Base URL'),
              onPressed: () {
                ApiClient().updateBaseUrl(_urlController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated Base URL to: ${_urlController.text.trim()}')),
                );
                widget.onSettingsChanged();
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
                'Tip for Reviewers:\n• Run mock server: dart run bin/mock_server.dart\n• If running on physical Android device: run `adb reverse tcp:8080 tcp:8080` and use `http://localhost:8080`.',
                style: TextStyle(fontSize: 12, color: Colors.indigo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
