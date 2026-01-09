import 'package:class_attendance_system/models/attendance_record.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/roster_entry.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const _dbName = 'attendance_system.db';
  static const _dbVersion = 2;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    debugPrint('🗄️ [DatabaseHelper] Opening new database connection');
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    debugPrint('🗄️ [DatabaseHelper] Initializing DB at $path');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          debugPrint(
            '🗄️ [DatabaseHelper] Upgrading schema v$oldVersion -> v$newVersion',
          );
          await _recreateSchema(db);
        }
      },
      onConfigure: (db) async {
        debugPrint('🗄️ [DatabaseHelper] Enabling foreign keys');
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _recreateSchema(Database db) async {
    await db.execute('DROP TABLE IF EXISTS attendance');
    await db.execute('DROP TABLE IF EXISTS roster');
    await db.execute('DROP TABLE IF EXISTS sessions');
    await db.execute('DROP TABLE IF EXISTS courses');
    await _createDB(db, _dbVersion);
  }

  Future<void> _createDB(Database db, int version) async {
    debugPrint('🗄️ [DatabaseHelper] Creating schema v$version');

    await db.execute('''
      CREATE TABLE courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseName TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,
        durationMinutes INTEGER NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        finalQrToken TEXT,
        FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE roster (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,
        studentName TEXT NOT NULL,
        UNIQUE(courseId, studentName),
        FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,
        sessionId INTEGER,
        studentName TEXT NOT NULL,
        checkInTime TEXT NOT NULL,
        checkOutTime TEXT,
        finalConfirmationTime TEXT,
        minutesOutside INTEGER NOT NULL DEFAULT 0,
        isValid INTEGER NOT NULL,
        FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE,
        FOREIGN KEY(sessionId) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');
  }

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
    return result.map(Course.fromMap).toList();
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

  Future<int> addRosterStudent(int courseId, String studentName) async {
    final db = await instance.database;
    final id = await db.insert('roster', {
      'courseId': courseId,
      'studentName': studentName,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    debugPrint(
      '🗄️ [DatabaseHelper] Roster add course=$courseId student=$studentName (id=$id)',
    );
    return id;
  }

  Future<List<RosterEntry>> getRosterEntries(int courseId) async {
    final db = await instance.database;
    final result = await db.query(
      'roster',
      where: 'courseId = ?',
      whereArgs: [courseId],
      orderBy: 'studentName ASC',
    );
    return result.map(RosterEntry.fromMap).toList();
  }

  Future<List<int>> getRegisteredCourseIds(String studentName) async {
    final db = await instance.database;
    final result = await db.query(
      'roster',
      columns: ['courseId'],
      where: 'studentName = ?',
      whereArgs: [studentName],
    );
    return result.map((row) => row['courseId'] as int).toList();
  }

  Future<List<Course>> getRegisteredCourses(String studentName) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT courses.* FROM courses
      INNER JOIN roster ON roster.courseId = courses.id
      WHERE roster.studentName = ?
      ORDER BY courses.courseName ASC
    ''',
      [studentName],
    );
    return result.map(Course.fromMap).toList();
  }

  Future<int> getRegistrationCount(String studentName) async {
    final db = await instance.database;
    final value = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM roster WHERE studentName = ?',
        [studentName],
      ),
    );
    return value ?? 0;
  }

  Future<void> removeRosterEntry(int rosterId) async {
    final db = await instance.database;
    final count = await db.delete(
      'roster',
      where: 'id = ?',
      whereArgs: [rosterId],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Removed roster id=$rosterId (rows=$count)',
    );
  }

  Future<void> removeRosterEntryByCourse(
    int courseId,
    String studentName,
  ) async {
    final db = await instance.database;
    final count = await db.delete(
      'roster',
      where: 'courseId = ? AND studentName = ?',
      whereArgs: [courseId, studentName],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Removed roster record course=$courseId student=$studentName (rows=$count)',
    );
  }

  Future<bool> isStudentRegistered(int courseId, String studentName) async {
    final db = await instance.database;
    final result = await db.query(
      'roster',
      columns: ['id'],
      where: 'courseId = ? AND studentName = ?',
      whereArgs: [courseId, studentName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> startSession({
    required int courseId,
    required int durationMinutes,
  }) async {
    final db = await instance.database;
    final activeSession = await getActiveSessionForCourse(courseId);
    if (activeSession != null) {
      throw StateError('A session is already active for this course.');
    }

    final id = await db.insert('sessions', {
      'courseId': courseId,
      'durationMinutes': durationMinutes,
      'startTime': DateTime.now().toIso8601String(),
      'isActive': 1,
    });
    debugPrint(
      '🗄️ [DatabaseHelper] Session started course=$courseId (id=$id)',
    );
    return id;
  }

  Future<Session?> getActiveSessionForCourse(int courseId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT sessions.*, courses.courseName FROM sessions
      INNER JOIN courses ON courses.id = sessions.courseId
      WHERE sessions.courseId = ? AND sessions.isActive = 1
      ORDER BY sessions.startTime DESC
      LIMIT 1
    ''',
      [courseId],
    );
    if (result.isEmpty) return null;
    return Session.fromMap(result.first);
  }

  Future<List<Session>> getActiveSessionsForStudent(String studentName) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT sessions.*, courses.courseName FROM sessions
      INNER JOIN roster ON roster.courseId = sessions.courseId
      INNER JOIN courses ON courses.id = sessions.courseId
      WHERE roster.studentName = ? AND sessions.isActive = 1
    ''',
      [studentName],
    );
    return result.map(Session.fromMap).toList();
  }

  Future<Session?> getSessionById(int sessionId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT sessions.*, courses.courseName FROM sessions
      INNER JOIN courses ON courses.id = sessions.courseId
      WHERE sessions.id = ?
      LIMIT 1
    ''',
      [sessionId],
    );
    if (result.isEmpty) return null;
    return Session.fromMap(result.first);
  }

  Future<Session?> getLatestSessionForCourse(int courseId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT sessions.*, courses.courseName FROM sessions
      INNER JOIN courses ON courses.id = sessions.courseId
      WHERE sessions.courseId = ?
      ORDER BY sessions.startTime DESC
      LIMIT 1
    ''',
      [courseId],
    );
    if (result.isEmpty) return null;
    return Session.fromMap(result.first);
  }

  Future<void> endSession(int sessionId) async {
    final db = await instance.database;
    final count = await db.update(
      'sessions',
      {'isActive': 0, 'endTime': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Ended session id=$sessionId (rows=$count)',
    );
  }

  Future<int> markAttendance({
    required int courseId,
    required String student,
    required bool isValid,
    int? sessionId,
  }) async {
    final db = await instance.database;
    final id = await db.insert('attendance', {
      'courseId': courseId,
      'sessionId': sessionId,
      'studentName': student,
      'checkInTime': DateTime.now().toIso8601String(),
      'isValid': isValid ? 1 : 0,
    });
    debugPrint(
      '🗄️ [DatabaseHelper] markAttendance course=$courseId session=$sessionId student=$student (id=$id)',
    );
    return id;
  }

  Future<bool> hasActiveAttendance(
    int courseId,
    String student, {
    int? sessionId,
  }) async {
    final db = await instance.database;
    final where = StringBuffer(
      'courseId = ? AND studentName = ? AND isValid = 1',
    );
    final args = <Object>[courseId, student];
    if (sessionId != null) {
      where.write(' AND sessionId = ?');
      args.add(sessionId);
    }
    final result = await db.query(
      'attendance',
      columns: ['id'],
      where: where.toString(),
      whereArgs: args,
      limit: 1,
    );
    final exists = result.isNotEmpty;
    debugPrint(
      '🗄️ [DatabaseHelper] hasActiveAttendance course=$courseId session=$sessionId student=$student -> $exists',
    );
    return exists;
  }

  Future<AttendanceRecord?> getActiveAttendanceRecord({
    required int courseId,
    required String studentName,
    int? sessionId,
  }) async {
    final db = await instance.database;
    final where = StringBuffer(
      'courseId = ? AND studentName = ? AND isValid = 1',
    );
    final args = <Object>[courseId, studentName];
    if (sessionId != null) {
      where.write(' AND sessionId = ?');
      args.add(sessionId);
    }

    final result = await db.query(
      'attendance',
      where: where.toString(),
      whereArgs: args,
      limit: 1,
    );
    if (result.isEmpty) return null;
    return AttendanceRecord.fromMap(result.first);
  }

  Future<List<AttendanceRecord>> getActiveAttendanceForStudent(
    String studentName,
  ) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT attendance.*, courses.courseName FROM attendance
      INNER JOIN courses ON courses.id = attendance.courseId
      WHERE attendance.studentName = ? AND attendance.isValid = 1
    ''',
      [studentName],
    );
    return result.map(AttendanceRecord.fromMap).toList();
  }

  Future<List<AttendanceRecord>> getAttendance({
    int? courseId,
    bool includeInvalid = true,
    String? studentName,
    bool requireFinalConfirmation = false,
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

    if (requireFinalConfirmation) {
      whereBuffer.write(' AND attendance.finalConfirmationTime IS NOT NULL');
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

    return result.map(AttendanceRecord.fromMap).toList();
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

  Future<void> updateMinutesOutside(
    int attendanceId,
    int minutesOutside, {
    bool closeRecord = false,
  }) async {
    final db = await instance.database;
    final Map<String, Object?> values = {'minutesOutside': minutesOutside};
    if (closeRecord) {
      values['isValid'] = 0;
      values['checkOutTime'] = DateTime.now().toIso8601String();
    }
    await db.update(
      'attendance',
      values,
      where: 'id = ?',
      whereArgs: [attendanceId],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] minutesOutside update attendance=$attendanceId value=$minutesOutside close=$closeRecord',
    );
  }

  Future<void> recordFinalConfirmation({
    required int courseId,
    required int sessionId,
    required String studentName,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final count = await db.update(
      'attendance',
      {'finalConfirmationTime': now, 'checkOutTime': now, 'isValid': 0},
      where:
          'courseId = ? AND sessionId = ? AND studentName = ? AND finalConfirmationTime IS NULL',
      whereArgs: [courseId, sessionId, studentName],
    );
    debugPrint(
      '🗄️ [DatabaseHelper] Final confirmation course=$courseId session=$sessionId student=$studentName (rows=$count)',
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
