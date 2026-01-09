import 'package:flutter/foundation.dart';
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
    debugPrint('📍 [GeofenceService] Current permission: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('📍 [GeofenceService] Requested permission -> $permission');
    }

    // 2. Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    debugPrint(
      '📍 [GeofenceService] Position lat=${position.latitude}, long=${position.longitude}',
    );

    // 3. Calculate distance between Student and Class Center
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      classLat,
      classLong,
    );
    debugPrint(
      '📍 [GeofenceService] Distance to class ${distance.toStringAsFixed(2)}m (radius=$radiusInMeters)',
    );

    // 4. Validate
    final inRange = distance <= radiusInMeters;
    debugPrint('📍 [GeofenceService] inRange=$inRange');
    return inRange;
  }
}
