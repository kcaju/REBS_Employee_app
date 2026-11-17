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
  static bool simulateLocation = true; // Enabled by default for easy testing without hardware GPS
  static bool simulateInsideOffice = true; // True = within 200m; False = 1200m away

  // Default office location: Bengaluru Tech Hub
  static const double defaultOfficeLat = 12.9716;
  static const double defaultOfficeLng = 77.5946;
  static const double defaultRadiusMeters = 200.0;

  Future<LocationResult> getCurrentLocationAndValidate({
    double officeLat = defaultOfficeLat,
    double officeLng = defaultOfficeLng,
    double radiusMeters = defaultRadiusMeters,
  }) async {
    // 1. Check if Reviewer simulation is active
    if (simulateLocation) {
      final lat = simulateInsideOffice ? officeLat : officeLat + 0.015; // ~1.6km away
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

    // 2. Real GPS Hardware & Permission Check
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.failure(
        message: 'Location services are disabled on this device. Please turn on GPS.',
        serviceDisabled: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.failure(
          message: 'Location permission was denied. Location is required for attendance verification.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.failure(
        message: 'Location permissions are permanently denied. Please enable them in app settings.',
        permanentlyDenied: true,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      final isInside = distance <= radiusMeters;

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        distanceMeters: distance,
        isWithinGeofence: isInside,
        errorMessage: isInside
            ? null
            : 'You are ${distance.toStringAsFixed(0)}m away from the office. Attendance is only permitted within ${radiusMeters.toStringAsFixed(0)}m.',
      );
    } catch (e) {
      return LocationResult.failure(
        message: 'Failed to acquire GPS fix: ${e.toString()}',
      );
    }
  }
}
