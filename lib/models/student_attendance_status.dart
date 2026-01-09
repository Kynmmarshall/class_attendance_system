class StudentAttendanceStatus {
  final String studentName;
  final bool isPresent;
  final DateTime? checkInTime;
  final DateTime? finalConfirmationTime;
  final int minutesOutside;

  const StudentAttendanceStatus({
    required this.studentName,
    required this.isPresent,
    this.checkInTime,
    this.finalConfirmationTime,
    this.minutesOutside = 0,
  });

  String get statusLabel => isPresent ? 'Present' : 'Absent';
}
