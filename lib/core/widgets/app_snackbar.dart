import 'package:flutter/material.dart';

class AppSnackBar {
  static String cleanErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    String msg = error.toString().trim();

    // Strip common technical prefixes
    msg = msg.replaceAll(RegExp(r'^(Exception|Error|DioException|ClientException):\s*', caseSensitive: false), '');
    msg = msg.replaceAll(RegExp(r'^DioException\s*\[[^\]]+\]:\s*', caseSensitive: false), '');

    // 1. Conflict / Duplicate
    if (msg.contains('409') || msg.toLowerCase().contains('conflict') || msg.toLowerCase().contains('already exists')) {
      return 'Attendance already recorded for this session.';
    }

    // 2. Blackout / Leave Reject
    if (msg.contains('422') || msg.toLowerCase().contains('blackout') || msg.toLowerCase().contains('leave_reject')) {
      if (msg.toLowerCase().contains('blackout')) {
        return 'Leave rejected: Company blackout dates active.';
      }
      if (msg.toLowerCase().contains('overlap')) {
        return 'Requested dates overlap with existing leave.';
      }
      if (msg.toLowerCase().contains('exceed') || msg.toLowerCase().contains('balance')) {
        return 'Requested days exceed available leave balance.';
      }
      return 'Leave submission rejected by server.';
    }

    // 3. Server 500 error
    if (msg.contains('500') || msg.toLowerCase().contains('internal server error')) {
      return 'Server error (500). Please try again later.';
    }

    // 4. Connectivity / Network issues
    if (msg.toLowerCase().contains('connection refused') ||
        msg.toLowerCase().contains('connection error') ||
        msg.toLowerCase().contains('network') ||
        msg.toLowerCase().contains('socketexception') ||
        msg.toLowerCase().contains('failed host lookup') ||
        msg.toLowerCase().contains('no internet') ||
        msg.toLowerCase().contains('no network connection')) {
      return 'No network connection. Active connectivity required.';
    }

    // 5. Timeout
    if (msg.toLowerCase().contains('timeout')) {
      return 'Request timed out. Please retry.';
    }

    // 6. Simulation & Geofence
    if (msg.toLowerCase().contains('simulate location')) {
      return 'Turn on the simulate location button to check in.';
    }
    if (msg.toLowerCase().contains('geofence') || msg.toLowerCase().contains('outside the permitted')) {
      return 'You are outside the 200m office geofence.';
    }

    // 7. Check for JSON "error": "..." payload
    final jsonMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(msg);
    if (jsonMatch != null) {
      return jsonMatch.group(1)!;
    }

    // 8. If multiline or overly long, take the first line and trim to max 75 characters
    final firstLine = msg.split('\n').first.trim();
    if (firstLine.length > 75) {
      return '${firstLine.substring(0, 72)}...';
    }
    return firstLine;
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: const Color(0xFF1E133A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0x3310B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showError(BuildContext context, dynamic error) {
    final cleanReason = cleanErrorMessage(error);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: const Color(0xFF1E133A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0x33EF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanReason,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
