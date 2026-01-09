class AttendanceRecord {
  final int? id;
  final int courseId;
  final int? sessionId;
  final String studentName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool isValid;
  final DateTime? finalConfirmationTime;
  final int minutesOutside;
  final String? courseName;
  final String? formUrl;

  const AttendanceRecord({
    this.id,
    required this.courseId,
    this.sessionId,
    required this.studentName,
    required this.checkInTime,
    this.checkOutTime,
    required this.isValid,
    this.finalConfirmationTime,
    this.minutesOutside = 0,
    this.courseName,
    this.formUrl,
  });

  AttendanceRecord copyWith({
    int? id,
    int? courseId,
    int? sessionId,
    String? studentName,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    bool? isValid,
    DateTime? finalConfirmationTime,
    int? minutesOutside,
    String? courseName,
    String? formUrl,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      sessionId: sessionId ?? this.sessionId,
      studentName: studentName ?? this.studentName,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      isValid: isValid ?? this.isValid,
      finalConfirmationTime:
          finalConfirmationTime ?? this.finalConfirmationTime,
      minutesOutside: minutesOutside ?? this.minutesOutside,
      courseName: courseName ?? this.courseName,
      formUrl: formUrl ?? this.formUrl,
    );
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      sessionId: map['sessionId'] as int?,
      studentName: map['studentName'] as String,
      checkInTime: DateTime.parse(map['checkInTime'] as String),
      checkOutTime:
          map['checkOutTime'] != null &&
              (map['checkOutTime'] as String).isNotEmpty
          ? DateTime.parse(map['checkOutTime'] as String)
          : null,
      isValid: (map['isValid'] as int) == 1,
      finalConfirmationTime:
          map['finalConfirmationTime'] != null &&
              (map['finalConfirmationTime'] as String).isNotEmpty
          ? DateTime.parse(map['finalConfirmationTime'] as String)
          : null,
      minutesOutside: (map['minutesOutside'] as int?) ?? 0,
      courseName: map['courseName'] as String?,
      formUrl: map['formUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'sessionId': sessionId,
      'studentName': studentName,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'isValid': isValid ? 1 : 0,
      'finalConfirmationTime': finalConfirmationTime?.toIso8601String(),
      'minutesOutside': minutesOutside,
      'formUrl': formUrl,
    }..removeWhere((key, value) => value == null);
  }

  bool get awaitingFinalConfirmation =>
      sessionId != null && finalConfirmationTime == null;
}
