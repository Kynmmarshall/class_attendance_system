class Course {
  final int? id;
  final String courseName;
  final double latitude;
  final double longitude;
  final double radius;

  const Course({
    this.id,
    required this.courseName,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  Course copyWith({
    int? id,
    String? courseName,
    double? latitude,
    double? longitude,
    double? radius,
  }) {
    return Course(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
    );
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int?,
      courseName: map['courseName'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseName': courseName,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    }..removeWhere((key, value) => value == null);
  }

  String buildQrPayload({int? sessionId, String phase = 'start'}) {
    final courseId = id ?? 0;
    final segments = <String>['CourseID:$courseId'];
    if (sessionId != null) {
      segments
        ..add('SessionID:$sessionId')
        ..add('Phase:$phase');
    }
    segments
      ..add('Lat:$latitude')
      ..add('Long:$longitude')
      ..add('Rad:$radius');
    return segments.join(',');
  }
}
