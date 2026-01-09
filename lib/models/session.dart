class Session {
  final int? id;
  final int courseId;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final String? finalQrToken;
  final String? courseName;

  const Session({
    this.id,
    required this.courseId,
    required this.durationMinutes,
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.finalQrToken,
    this.courseName,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      durationMinutes: map['durationMinutes'] as int,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null && (map['endTime'] as String).isNotEmpty
          ? DateTime.parse(map['endTime'] as String)
          : null,
      isActive: (map['isActive'] as int) == 1,
      finalQrToken: map['finalQrToken'] as String?,
      courseName: map['courseName'] as String?,
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
    }..removeWhere((key, value) => value == null);
  }

  bool get isFinalized => !isActive && endTime != null;

  Duration get remainingDuration {
    final end = endTime ?? startTime.add(Duration(minutes: durationMinutes));
    return end.difference(DateTime.now());
  }
}
