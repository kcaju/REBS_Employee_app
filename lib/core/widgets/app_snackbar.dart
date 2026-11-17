import 'package:flutter/material.dart';
import '../network/api_client.dart';

class AppSnackBar {
  static String? _getActiveScenarioTag() {
    final scenario = ApiConfig.activeScenario;
    if (scenario == 'normal' || scenario.isEmpty) return null;
    switch (scenario) {
      case 'slow':
        return 'SCENARIO: SLOW TIMEOUT';
      case 'error':
        return 'SCENARIO: 500 SERVER ERROR';
      case 'conflict':
        return 'SCENARIO: 409 DUPLICATE CONFLICT';
      case 'leave_reject':
        return 'SCENARIO: 422 LEAVE REJECT';
      default:
        return 'SCENARIO: ${scenario.toUpperCase()}';
    }
  }

  static String cleanErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    String msg = error.toString().trim();

    // Strip common technical prefixes
    msg = msg.replaceAll(RegExp(r'^(Exception|Error):\s*', caseSensitive: false), '');
    msg = msg.replaceAll(RegExp(r'^DioException\s*\[[^\]]+\]:\s*', caseSensitive: false), '');

    // Extract JSON error payload if present
    final jsonMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(msg);
    if (jsonMatch != null) {
      msg = jsonMatch.group(1)!;
    }

    // Specific network or HTTP code mapping if raw Dio message
    if (msg.contains('DioException') || msg.contains('SocketException')) {
      if (msg.contains('409') || msg.toLowerCase().contains('conflict')) {
        return 'Attendance record already exists for this slot.';
      }
      if (msg.contains('500') || msg.toLowerCase().contains('internal server error')) {
        return 'Server error (500). Please try again later.';
      }
      if (msg.toLowerCase().contains('connection') ||
          msg.toLowerCase().contains('network') ||
          msg.toLowerCase().contains('socket') ||
          msg.toLowerCase().contains('failed host lookup')) {
        return 'No network connection. Active connectivity required.';
      }
      if (msg.toLowerCase().contains('timeout')) {
        return 'Request timed out. Please retry.';
      }
    }

    // Return the clean message in full without any artificial truncation or dots
    return msg.split('\n').first.trim();
  }

  static void showSuccess(BuildContext context, String message) {
    final scenarioTag = _getActiveScenarioTag();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: const Color(0xFF1E133A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0x3310B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (scenarioTag != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33F59E0B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        scenarioTag,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showError(BuildContext context, dynamic error) {
    final scenarioTag = _getActiveScenarioTag();
    final cleanReason = cleanErrorMessage(error);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: const Color(0xFF1E133A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0x33EF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (scenarioTag != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33F59E0B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        scenarioTag,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    cleanReason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
