import 'package:class_attendance_system/models/attendance_record.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    debugPrint('🗄️ [DatabaseHelper] Opening new database connection');
    _database = await _initDB('attendance_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    debugPrint('🗄️ [DatabaseHelper] Initializing DB at $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        debugPrint('🗄️ [DatabaseHelper] Enabling foreign keys');
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    debugPrint('🗄️ [DatabaseHelper] Creating schema v$version');
    // Stores Course details + Geofence Center (Lat/Lng)
    await db.execute('''
    CREATE TABLE courses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      courseName TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      radius REAL NOT NULL
    )
    ''');

    // Stores Attendance Records
    await db.execute('''
    CREATE TABLE attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      courseId INTEGER NOT NULL,
      studentName TEXT NOT NULL,
      checkInTime TEXT NOT NULL,
      checkOutTime TEXT,
      isValid INTEGER NOT NULL,
      FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE
    )
    ''');
  }

  // FR3: Unique QR generation per course (saving the course data)
  Future<int> createCourse(Course course) async {
    final db = await instance.database;
    final id = await db.insert('courses', course.toMap());
    debugPrint(
      '🗄️ [DatabaseHelper] Created course ${course.courseName} (id=$id)',
    );
    return id;
  }

  Future<List<Course>> getAllCourses() async {
    final db = await instance.database;
    final result = await db.query('courses', orderBy: 'courseName ASC');
    debugPrint('🗄️ [DatabaseHelper] Loaded ${result.length} course(s)');
    return result.map((map) => Course.fromMap(map)).toList();
  }

  Future<Course?> getCourseById(int id) async {
    final db = await instance.database;
    final result = await db.query('courses', where: 'id = ?', whereArgs: [id]);
    debugPrint(
      '🗄️ [DatabaseHelper] getCourseById($id) -> ${result.isNotEmpty}',
    );
    if (result.isEmpty) return null;
    return Course.fromMap(result.first);
  }

  Future<int> updateCourse(Course course) async {
    final db = await instance.database;
    if (course.id == null) {
      throw ArgumentError('Cannot update course without an id');
    }
    final count = await db.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Updated course id=${course.id} (rows=$count)',
    );
    return count;
  }

  Future<int> deleteCourse(int id) async {
    final db = await instance.database;
    final count = await db.delete('courses', where: 'id = ?', whereArgs: [id]);
    debugPrint('🗄️ [DatabaseHelper] Deleted course id=$id (rows=$count)');
    return count;
  }

  // FR7: Record student info + timestamp
  Future<int> markAttendance(int courseId, String student, bool isValid) async {
    final db = await instance.database;
    final id = await db.insert('attendance', {
      'courseId': courseId,
      'studentName': student,
      'checkInTime': DateTime.now().toIso8601String(),
      'isValid': isValid ? 1 : 0,
    });
    debugPrint(
      '🗄️ [DatabaseHelper] markAttendance course=$courseId student=$student inRange=$isValid (id=$id)',
    );
    return id;
  }

  Future<bool> hasActiveAttendance(int courseId, String student) async {
    final db = await instance.database;
    final result = await db.query(
      'attendance',
      columns: ['id'],
      where: 'courseId = ? AND studentName = ? AND isValid = 1',
      whereArgs: [courseId, student],
      limit: 1,
    );
    final exists = result.isNotEmpty;
    debugPrint(
      '🗄️ [DatabaseHelper] hasActiveAttendance course=$courseId student=$student -> $exists',
    );
    return exists;
  }

  Future<List<AttendanceRecord>> getAttendance({
    int? courseId,
    bool includeInvalid = true,
    String? studentName,
  }) async {
    final db = await instance.database;
    final whereBuffer = StringBuffer('1 = 1');
    final args = <Object?>[];

    if (courseId != null) {
      whereBuffer.write(' AND attendance.courseId = ?');
      args.add(courseId);
    }

    if (!includeInvalid) {
      whereBuffer.write(' AND attendance.isValid = 1');
    }

    if (studentName != null && studentName.isNotEmpty) {
      whereBuffer.write(' AND attendance.studentName = ?');
      args.add(studentName);
    }

    debugPrint(
      '🗄️ [DatabaseHelper] Fetching attendance course=$courseId includeInvalid=$includeInvalid student=$studentName',
    );

    final result = await db.rawQuery('''
      SELECT attendance.*, courses.courseName
      FROM attendance
      INNER JOIN courses ON attendance.courseId = courses.id
      WHERE ${whereBuffer.toString()}
      ORDER BY attendance.checkInTime DESC
    ''', args);

    return result.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<void> updateCheckoutTime(int attendanceId) async {
    final db = await instance.database;
    final count = await db.update(
      'attendance',
      {'checkOutTime': DateTime.now().toIso8601String(), 'isValid': 0},
      where: 'id = ?',
      whereArgs: [attendanceId],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Updated checkout for attendance=$attendanceId (rows=$count)',
    );
  }

  Future<int> purgeExpiredAttendance(Duration maxAway) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(maxAway).toIso8601String();
    final count = await db.update(
      'attendance',
      {'isValid': 0, 'checkOutTime': DateTime.now().toIso8601String()},
      where: 'isValid = 1 AND checkInTime <= ?',
      whereArgs: [cutoff],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Purged $count attendance rows older than $cutoff',
    );
    return count;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      debugPrint('🗄️ [DatabaseHelper] Closing database');
      await db.close();
    }
  }
}
