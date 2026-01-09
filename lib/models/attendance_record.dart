class AttendanceRecord {
  final int? id;
  final int courseId;
  final String studentName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool isValid;
  final String? courseName;

  const AttendanceRecord({
    this.id,
    required this.courseId,
    required this.studentName,
    required this.checkInTime,
    this.checkOutTime,
    required this.isValid,
    this.courseName,
  });

  AttendanceRecord copyWith({
    int? id,
    int? courseId,
    String? studentName,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    bool? isValid,
    String? courseName,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      studentName: studentName ?? this.studentName,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      isValid: isValid ?? this.isValid,
      courseName: courseName ?? this.courseName,
    );
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      studentName: map['studentName'] as String,
      checkInTime: DateTime.parse(map['checkInTime'] as String),
      checkOutTime:
          map['checkOutTime'] != null &&
              (map['checkOutTime'] as String).isNotEmpty
          ? DateTime.parse(map['checkOutTime'] as String)
          : null,
      isValid: (map['isValid'] as int) == 1,
      courseName: map['courseName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'studentName': studentName,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'isValid': isValid ? 1 : 0,
    }..removeWhere((key, value) => value == null);
  }
}
