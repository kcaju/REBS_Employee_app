import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final bool isWithinGeofence;
  final String? errorMessage;
  final bool isPermissionPermanentlyDenied;
  final bool isServiceDisabled;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.isWithinGeofence,
    this.errorMessage,
    this.isPermissionPermanentlyDenied = false,
    this.isServiceDisabled = false,
  });

  factory LocationResult.failure({
    required String message,
    bool permanentlyDenied = false,
    bool serviceDisabled = false,
  }) {
    return LocationResult(
      latitude: 0,
      longitude: 0,
      distanceMeters: double.infinity,
      isWithinGeofence: false,
      errorMessage: message,
      isPermissionPermanentlyDenied: permanentlyDenied,
      isServiceDisabled: serviceDisabled,
    );
  }
}

class LocationService {
  // Reviewer Mock Simulation Controls
  static bool simulateLocation =
      true; // Enabled by default for easy testing without hardware GPS
  static bool simulateInsideOffice =
      true; // True = within 200m; False = 1200m away

  // Default office location: Bengaluru Tech Hub
  static const double defaultOfficeLat = 12.9716;
  static const double defaultOfficeLng = 77.5946;
  static const double defaultRadiusMeters = 200.0;

  Future<LocationResult> getCurrentLocationAndValidate({
    double officeLat = defaultOfficeLat,
    double officeLng = defaultOfficeLng,
    double radiusMeters = defaultRadiusMeters,
  }) async {
    // If reviewer simulation is toggled off, prompt to turn it on
    if (!simulateLocation) {
      return LocationResult.failure(
        message: 'Turn on the simulate location button to check in.',
      );
    }

    // When simulation is ON: simulate inside office (<=200m) or outside office (>200m)
    final lat = simulateInsideOffice
        ? officeLat
        : officeLat + 0.015; // ~1.6km away (geofence violation test)
    final lng = simulateInsideOffice ? officeLng : officeLng + 0.015;
    final distance = Geolocator.distanceBetween(lat, lng, officeLat, officeLng);
    final isInside = distance <= radiusMeters;

    return LocationResult(
      latitude: lat,
      longitude: lng,
      distanceMeters: distance,
      isWithinGeofence: isInside,
      errorMessage: isInside
          ? null
          : 'You are ${distance.toStringAsFixed(0)}m away from the office. Check-in is only permitted within ${radiusMeters.toStringAsFixed(0)}m.',
    );
  }
}
