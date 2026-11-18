import 'package:geolocator/geolocator.dart';

/// Reviewer and Development Location Configuration
///
/// When [useMockLocation] is enabled (true), the app uses [mockLatitude] and [mockLongitude]
/// instead of querying actual device GPS sensors.
/// When [useMockLocation] is disabled (false, DEFAULT), the app queries the device's real GPS hardware.
class LocationConfig {
  /// Whether reviewer mock location mode is enabled.
  /// Defaults to false so real device GPS is used by default on app launch and restart.
  static bool useMockLocation = false;

  /// Default configured office coordinates (matches mock API employee profile)
  static const String defaultOfficeName = 'REBS Office';
  static const double defaultOfficeLat = 10.382439;
  static const double defaultOfficeLng = 76.288664;
  static const double defaultRadiusMeters = 200.0;

  /// Configurable simulated employee coordinates (used only when [useMockLocation] is true).
  static double mockLatitude = defaultOfficeLat;
  static double mockLongitude = defaultOfficeLng;

  /// Presets for easy reviewer toggling
  static void setInsideOffice({double officeLat = defaultOfficeLat, double officeLng = defaultOfficeLng}) {
    useMockLocation = true;
    mockLatitude = officeLat;
    mockLongitude = officeLng;
  }

  static void setOutsideOffice({double officeLat = defaultOfficeLat, double officeLng = defaultOfficeLng}) {
    useMockLocation = true;
    // ~2.3 km away from office coordinates to guarantee geofence violation
    mockLatitude = officeLat + 0.015;
    mockLongitude = officeLng + 0.015;
  }
}

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
  // Backward compatibility mappings to LocationConfig
  static bool get simulateLocation => LocationConfig.useMockLocation;
  static set simulateLocation(bool val) => LocationConfig.useMockLocation = val;

  static bool get simulateInsideOffice =>
      LocationConfig.mockLatitude == LocationConfig.defaultOfficeLat &&
      LocationConfig.mockLongitude == LocationConfig.defaultOfficeLng;

  static set simulateInsideOffice(bool inside) {
    if (inside) {
      LocationConfig.setInsideOffice();
    } else {
      LocationConfig.setOutsideOffice();
    }
  }

  static const double defaultOfficeLat = LocationConfig.defaultOfficeLat;
  static const double defaultOfficeLng = LocationConfig.defaultOfficeLng;
  static const double defaultRadiusMeters = LocationConfig.defaultRadiusMeters;

  /// Validates employee location against configured office coordinates.
  ///
  /// 1. Gets the employee's current GPS coordinates (from Real Device GPS or Mock mode).
  /// 2. Handles location disabled, denied permission, and unavailable location.
  /// 3. Calculates the distance between employee and office coordinates.
  /// 4. Allows attendance (check-in/check-out) only if distance <= [radiusMeters] (200m).
  Future<LocationResult> getCurrentLocationAndValidate({
    double officeLat = defaultOfficeLat,
    double officeLng = defaultOfficeLng,
    double radiusMeters = defaultRadiusMeters,
  }) async {
    double employeeLatitude;
    double employeeLongitude;

    // 1. Determine employee coordinates: Real Device GPS vs Reviewer Mock
    if (LocationConfig.useMockLocation) {
      employeeLatitude = LocationConfig.mockLatitude;
      employeeLongitude = LocationConfig.mockLongitude;
    } else {
      // 1. Check if location services (GPS) are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          message:
              'Location services are disabled. Please turn on GPS in your device settings to record attendance.',
          serviceDisabled: true,
        );
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            message:
                'Location permission was denied. Please allow location access to record attendance.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          message:
              'Location permissions are permanently denied. Please enable them in app settings to record attendance.',
          permanentlyDenied: true,
        );
      }

      // 3. Acquire current GPS position
      Position? position;

      // Try last known cached position first
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // Fetch fresh position with medium accuracy (works both indoors via Wi-Fi/Cell and outdoors via GNSS)
      try {
        final freshPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        position = freshPosition;
      } catch (_) {
        // Fallback to low accuracy if needed
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
              ),
            );
          } catch (_) {}
        }
      }

      if (position == null) {
        return LocationResult.failure(
          message:
              'Location unavailable. Unable to acquire GPS coordinates. Please ensure GPS is enabled and try again.',
        );
      }

      employeeLatitude = position.latitude;
      employeeLongitude = position.longitude;
    }

    // 2. Calculate distance between employee and configured office coordinates
    final double distance = Geolocator.distanceBetween(
      employeeLatitude,
      employeeLongitude,
      officeLat,
      officeLng,
    );

    // 3. Allow attendance only if within configured radius (200 metres)
    final bool isWithinGeofence = distance <= radiusMeters;
    final String distanceDisplay = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(1)} km'
        : '${distance.toStringAsFixed(0)} metres';

    return LocationResult(
      latitude: employeeLatitude,
      longitude: employeeLongitude,
      distanceMeters: distance,
      isWithinGeofence: isWithinGeofence,
      errorMessage: isWithinGeofence
          ? null
          : 'You are $distanceDisplay away from the office. Attendance is permitted only within ${radiusMeters.toStringAsFixed(0)} metres of the office.',
    );
  }
}
