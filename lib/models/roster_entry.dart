class RosterEntry {
  final int? id;
  final int courseId;
  final String studentName;

  const RosterEntry({
    this.id,
    required this.courseId,
    required this.studentName,
  });

  factory RosterEntry.fromMap(Map<String, dynamic> map) {
    return RosterEntry(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      studentName: map['studentName'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'courseId': courseId, 'studentName': studentName}
      ..removeWhere((key, value) => value == null);
  }
}
