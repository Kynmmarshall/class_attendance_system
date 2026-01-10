import 'dart:typed_data';

class Session {
  final int? id;
  final int courseId;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final String? finalQrToken;
  final String? courseName;
  final DateTime? finalQrExpiresAt;
  final DateTime? reportGeneratedAt;
  final Uint8List? reportPdf;

  const Session({
    this.id,
    required this.courseId,
    required this.durationMinutes,
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.finalQrToken,
    this.courseName,
    this.finalQrExpiresAt,
    this.reportGeneratedAt,
    this.reportPdf,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final stringValue = value.toString();
      if (stringValue.isEmpty) return null;
      return DateTime.tryParse(stringValue);
    }

    return Session(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      durationMinutes: map['durationMinutes'] as int,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: parseDate(map['endTime']),
      isActive: (map['isActive'] as int) == 1,
      finalQrToken: map['finalQrToken'] as String?,
      courseName: map['courseName'] as String?,
      finalQrExpiresAt: parseDate(map['finalQrExpiresAt']),
      reportGeneratedAt: parseDate(map['reportGeneratedAt']),
      reportPdf: _asBytes(map['reportPdf']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'durationMinutes': durationMinutes,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'finalQrToken': finalQrToken,
      'finalQrExpiresAt': finalQrExpiresAt?.toIso8601String(),
      'reportGeneratedAt': reportGeneratedAt?.toIso8601String(),
      'reportPdf': reportPdf,
    }..removeWhere((key, value) => value == null);
  }

  bool get isFinalized => !isActive && endTime != null;

  Duration get remainingDuration {
    final plannedEnd = endTime ??
        startTime.add(Duration(minutes: durationMinutes));
    return plannedEnd.difference(DateTime.now());
  }

  bool get finalQrActive {
    if (isActive) return false;
    if (finalQrExpiresAt == null) return false;
    return DateTime.now().isBefore(finalQrExpiresAt!);
  }

  bool get finalQrExpired {
    if (finalQrExpiresAt == null) return false;
    return DateTime.now().isAfter(finalQrExpiresAt!);
  }

  bool get reportReady => reportPdf != null;

  static Uint8List? _asBytes(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }
}
