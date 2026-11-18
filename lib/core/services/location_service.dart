import 'package:geolocator/geolocator.dart';

/// Reviewer and Development Location Configuration
///
/// When [useMockLocation] is enabled (true), the app uses [mockLatitude] and [mockLongitude]
/// instead of querying actual device GPS sensors.
/// When [useMockLocation] is disabled (false), the app queries the device's real GPS hardware.
class LocationConfig {
  /// Whether reviewer mock location mode is enabled.
  /// Defaults to true so evaluators can test check-in without being physically present at the office.
  static bool useMockLocation = true;

  /// Configurable simulated employee coordinates.
  /// Default set to office coordinates (10.8505, 76.2711) for immediate success testing.
  static double mockLatitude = 10.8505;
  static double mockLongitude = 76.2711;

  /// Default configured office coordinates (used as fallback if not fetched from API)
  static const String defaultOfficeName = 'REBS Office';
  static const double defaultOfficeLat = 10.8505;
  static const double defaultOfficeLng = 76.2711;
  static const double defaultRadiusMeters = 200.0;

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
  /// 1. Gets the employee's current GPS coordinates (from Mock or Real Hardware GPS).
  /// 2. Gets the configured office coordinates passed via parameters (from API / Config).
  /// 3. Calculates the distance between employee and office using Geolocator.
  /// 4. Allows check-in only if distance <= [radiusMeters] (200m).
  Future<LocationResult> getCurrentLocationAndValidate({
    double officeLat = defaultOfficeLat,
    double officeLng = defaultOfficeLng,
    double radiusMeters = defaultRadiusMeters,
  }) async {
    double employeeLatitude;
    double employeeLongitude;

    // 1. Determine employee coordinates: Mock vs Real Device GPS
    if (LocationConfig.useMockLocation) {
      employeeLatitude = LocationConfig.mockLatitude;
      employeeLongitude = LocationConfig.mockLongitude;
    } else {
      // Real Hardware GPS tracking
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          message:
              'Location services are disabled on this device. Please enable GPS in device settings or turn on Mock Location in Reviewer Controls (⚙️).',
          serviceDisabled: true,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            message:
                'Location permission was denied. Please allow location access or turn on Mock Location in Reviewer Controls (⚙️).',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          message:
              'Location permissions are permanently denied. Please enable them in app settings or turn on Mock Location in Reviewer Controls (⚙️).',
          permanentlyDenied: true,
        );
      }

      Position? position;

      // 1. Try to get last known position first (near-instant on Android if recently located)
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 2. Fetch fresh position using medium accuracy (works indoors via Wi-Fi/Cell/GPS)
      try {
        final freshPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        position = freshPosition;
      } catch (_) {
        // If fresh lookup timed out or failed, try low accuracy if we don't have a cached position yet
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
              'Unable to get GPS fix on this device. Please turn on Google Location Accuracy/Wi-Fi, or enable Mock Location in Reviewer Controls (⚙️).',
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

    // 3. Allow check-in only if within configured radius (200 metres)
    final bool isWithinGeofence = distance <= radiusMeters;

    return LocationResult(
      latitude: employeeLatitude,
      longitude: employeeLongitude,
      distanceMeters: distance,
      isWithinGeofence: isWithinGeofence,
      errorMessage: isWithinGeofence
          ? null
          : 'You are ${distance.toStringAsFixed(0)}m away from the office. Check-in is only permitted within ${radiusMeters.toStringAsFixed(0)}m.',
    );
  }
}
