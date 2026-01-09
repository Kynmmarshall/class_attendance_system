import 'package:geolocator/geolocator.dart';

class GeofenceService {
  // FR5 & FR6: Geofence validation and deny outside geofence
  Future<bool> isStudentInRange(
    double classLat,
    double classLong,
    double radiusInMeters,
  ) async {
    // 1. Get current permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 2. Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 3. Calculate distance between Student and Class Center
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      classLat,
      classLong,
    );

    // 4. Validate
    return distance <= radiusInMeters;
  }
}
