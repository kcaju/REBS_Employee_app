import 'dart:io';
import 'package:employee_app/server/embedded_mock_server.dart';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8085') ?? 8085;
  final server = EmbeddedMockServer.instance;
  final actualPort = await server.start(defaultPort: port);

  // ignore: avoid_print
  print('====================================================');
  // ignore: avoid_print
  print('  REBS HRMS Mock Server running on port $actualPort');
  // ignore: avoid_print
  print('  URL: http://localhost:$actualPort');
  // ignore: avoid_print
  print('  Android Emulator: http://10.0.2.2:$actualPort');
  // ignore: avoid_print
  print('====================================================');
}
