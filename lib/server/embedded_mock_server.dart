import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class EmbeddedMockServer {
  static EmbeddedMockServer? _instance;
  static EmbeddedMockServer get instance => _instance ??= EmbeddedMockServer();

  HttpServer? _server;
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 8085;

  final MockApiServer apiServer = MockApiServer();

  Future<int> start({int defaultPort = 8085}) async {
    if (_server != null) return _server!.port;

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(apiServer.router.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, defaultPort);
      return _server!.port;
    } catch (_) {
      // If port 8085 is in use, bind to any available port
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      return _server!.port;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Idempotency-Key, X-Mock-Scenario',
          });
        }
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Idempotency-Key, X-Mock-Scenario',
        });
      };
    };
  }
}

class MockApiServer {
  final Router router = Router();

  final Set<String> _processedIdempotencyKeys = {};
  final List<Map<String, dynamic>> _attendanceEvents = [];
  final List<Map<String, dynamic>> _leaveRequests = [
    {
      'id': 'LR-001',
      'employee_id': 'EMP-1049',
      'leave_type': 'Casual',
      'start_date': '2026-11-01',
      'end_date': '2026-11-02',
      'reason': 'Family gathering out of station',
      'status': 'Approved',
      'created_at': '2026-10-25T10:00:00Z',
    },
    {
      'id': 'LR-002',
      'employee_id': 'EMP-1049',
      'leave_type': 'Sick',
      'start_date': '2026-11-10',
      'end_date': '2026-11-10',
      'reason': 'Viral fever and doctor consultation',
      'status': 'Approved',
      'created_at': '2026-11-09T18:30:00Z',
    }
  ];

  int _casualLeaveBalance = 8;
  int _sickLeaveBalance = 5;

  MockApiServer() {
    _initializeInitialAttendance();
    _setupRoutes();
  }

  void _initializeInitialAttendance() {
    _attendanceEvents.addAll([
      {
        'id': 'att_1',
        'client_event_id': 'seed_1',
        'employee_id': 'EMP-1049',
        'date': '2026-11-12',
        'type': 'CHECK_IN',
        'timestamp': '2026-11-12T09:05:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_2',
        'client_event_id': 'seed_2',
        'employee_id': 'EMP-1049',
        'date': '2026-11-12',
        'type': 'CHECK_OUT',
        'timestamp': '2026-11-12T18:15:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_3',
        'client_event_id': 'seed_3',
        'employee_id': 'EMP-1049',
        'date': '2026-11-13',
        'type': 'CHECK_IN',
        'timestamp': '2026-11-13T09:12:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_4',
        'client_event_id': 'seed_4',
        'employee_id': 'EMP-1049',
        'date': '2026-11-13',
        'type': 'CHECK_OUT',
        'timestamp': '2026-11-13T17:45:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_5',
        'client_event_id': 'seed_5',
        'employee_id': 'EMP-1049',
        'date': '2026-11-14',
        'type': 'CHECK_IN',
        'timestamp': '2026-11-14T08:55:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_6',
        'client_event_id': 'seed_6',
        'employee_id': 'EMP-1049',
        'date': '2026-11-14',
        'type': 'CHECK_OUT',
        'timestamp': '2026-11-14T18:30:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_7',
        'client_event_id': 'seed_7',
        'employee_id': 'EMP-1049',
        'date': '2026-11-15',
        'type': 'CHECK_IN',
        'timestamp': '2026-11-15T09:00:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_8',
        'client_event_id': 'seed_8',
        'employee_id': 'EMP-1049',
        'date': '2026-11-15',
        'type': 'CHECK_OUT',
        'timestamp': '2026-11-15T18:00:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_9',
        'client_event_id': 'seed_9',
        'employee_id': 'EMP-1049',
        'date': '2026-11-16',
        'type': 'CHECK_IN',
        'timestamp': '2026-11-16T09:10:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
      {
        'id': 'att_10',
        'client_event_id': 'seed_10',
        'employee_id': 'EMP-1049',
        'date': '2026-11-16',
        'type': 'CHECK_OUT',
        'timestamp': '2026-11-16T18:05:00Z',
        'latitude': 12.9716,
        'longitude': 77.5946,
      },
    ]);
  }

  void _setupRoutes() {
    router.get('/employee/me', (Request request) async {
      final scenario = _checkScenario(request);
      if (scenario != null) return scenario;

      return _jsonResponse({
        'id': 'EMP-1049',
        'name': 'Alex Morgan',
        'email': 'alex.morgan@rebs.io',
        'department': 'Mobile Engineering',
        'role': 'Senior Flutter Engineer',
        'office_config': {
          'latitude': 12.9716,
          'longitude': 77.5946,
          'radius_meters': 200.0,
          'office_name': 'REBS Tech Hub - Bengaluru',
          'timezone': 'Asia/Kolkata',
        }
      });
    });

    router.get('/attendance', (Request request) async {
      final scenario = _checkScenario(request);
      if (scenario != null) return scenario;

      return _jsonResponse({
        'records': _attendanceEvents,
      });
    });

    router.post('/attendance/events', (Request request) async {
      final scenario = _checkScenario(request);
      if (scenario != null) return scenario;

      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final clientEventId = (request.headers['x-idempotency-key'] ??
          body['client_event_id'] ??
          '') as String;

      if (clientEventId.isEmpty) {
        return _jsonResponse({'error': 'Missing client_event_id or X-Idempotency-Key'}, status: 400);
      }

      // Idempotency check: if already processed, return acknowledged response without creating duplicate
      if (_processedIdempotencyKeys.contains(clientEventId)) {
        final existing = _attendanceEvents.firstWhere(
          (e) => e['client_event_id'] == clientEventId,
          orElse: () => body,
        );
        return _jsonResponse({
          'message': 'Event already acknowledged (idempotent)',
          'event': existing,
          'status': 'acknowledged',
        }, status: 200);
      }

      final type = body['type'] as String?;
      final date = body['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10);

      if (type == 'CHECK_IN') {
        final alreadyCheckedIn = _attendanceEvents.any((e) => e['date'] == date && e['type'] == 'CHECK_IN');
        if (alreadyCheckedIn) {
          return _jsonResponse({
            'error': 'Attendance check-in already recorded for date: $date',
            'code': 'DUPLICATE_CHECK_IN'
          }, status: 409);
        }
      }

      final newRecord = {
        'id': 'att_${DateTime.now().millisecondsSinceEpoch}',
        'client_event_id': clientEventId,
        'employee_id': body['employee_id'] ?? 'EMP-1049',
        'date': date,
        'type': type,
        'timestamp': body['timestamp'] ?? DateTime.now().toIso8601String(),
        'latitude': body['latitude'],
        'longitude': body['longitude'],
      };

      _processedIdempotencyKeys.add(clientEventId);
      _attendanceEvents.add(newRecord);

      return _jsonResponse({
        'message': 'Attendance event recorded successfully',
        'event': newRecord,
      }, status: 201);
    });

    router.get('/leave/balance', (Request request) async {
      final scenario = _checkScenario(request);
      if (scenario != null) return scenario;

      return _jsonResponse({
        'employee_id': 'EMP-1049',
        'casual_leave_remaining': _casualLeaveBalance,
        'sick_leave_remaining': _sickLeaveBalance,
      });
    });

    router.get('/leave/requests', (Request request) async {
      final scenario = _checkScenario(request);
      if (scenario != null) return scenario;

      return _jsonResponse({
        'requests': _leaveRequests,
      });
    });

    router.post('/leave/requests', (Request request) async {
      final scenario = _checkScenario(request);
      if (scenario != null) return scenario;

      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final leaveType = body['leave_type'] as String;
      final startDate = DateTime.parse(body['start_date'] as String);
      final endDate = DateTime.parse(body['end_date'] as String);
      final reason = (body['reason'] as String?)?.trim() ?? '';

      if (reason.replaceAll(RegExp(r'\s+'), '').length < 10) {
        return _jsonResponse({'error': 'Reason must contain at least 10 non-whitespace characters'}, status: 422);
      }

      if (endDate.isBefore(startDate)) {
        return _jsonResponse({'error': 'End date cannot be before start date'}, status: 422);
      }

      for (final req in _leaveRequests) {
        if (req['status'] == 'Approved' || req['status'] == 'Pending') {
          final reqStart = DateTime.parse(req['start_date'] as String);
          final reqEnd = DateTime.parse(req['end_date'] as String);
          if (!startDate.isAfter(reqEnd) && !endDate.isBefore(reqStart)) {
            return _jsonResponse({
              'error': 'Requested leave dates overlap with an existing ${req['status']} request (${req['start_date']} to ${req['end_date']})',
              'code': 'LEAVE_OVERLAP'
            }, status: 422);
          }
        }
      }

      final daysRequested = endDate.difference(startDate).inDays + 1;
      final available = leaveType == 'Casual' ? _casualLeaveBalance : _sickLeaveBalance;
      if (daysRequested > available) {
        return _jsonResponse({
          'error': 'Requested days ($daysRequested) exceed available $leaveType leave balance ($available)',
          'code': 'INSUFFICIENT_BALANCE'
        }, status: 422);
      }

      if (leaveType == 'Casual') {
        _casualLeaveBalance -= daysRequested;
      } else {
        _sickLeaveBalance -= daysRequested;
      }

      final newRequest = {
        'id': 'LR-${DateTime.now().millisecondsSinceEpoch}',
        'employee_id': 'EMP-1049',
        'leave_type': leaveType,
        'start_date': body['start_date'],
        'end_date': body['end_date'],
        'reason': reason,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      _leaveRequests.insert(0, newRequest);

      return _jsonResponse({
        'message': 'Leave application submitted successfully',
        'request': newRequest,
      }, status: 201);
    });

    router.post('/debug/reset', (Request request) async {
      _processedIdempotencyKeys.clear();
      _attendanceEvents.clear();
      _leaveRequests.clear();
      _casualLeaveBalance = 8;
      _sickLeaveBalance = 5;
      _initializeInitialAttendance();
      return _jsonResponse({'message': 'Server state reset to initial seed values'});
    });
  }

  Response? _checkScenario(Request request) {
    final scenario = request.headers['x-mock-scenario'] ??
        request.url.queryParameters['scenario'];

    if (scenario == 'error') {
      return _jsonResponse({'error': 'Simulated 500 Internal Server Error'}, status: 500);
    }
    if (scenario == 'conflict') {
      return _jsonResponse({'error': 'Simulated 409 Conflict: Attendance already exists'}, status: 409);
    }
    if (scenario == 'leave_reject') {
      return _jsonResponse({'error': 'Simulated 422 Server Rejection: Blackout dates applied'}, status: 422);
    }
    return null;
  }

  Response _jsonResponse(Map<String, dynamic> data, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }
}
