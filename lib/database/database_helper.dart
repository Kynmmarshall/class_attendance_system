import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
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
      isValid INTEGER NOT NULL
    )
    ''');
  }

  // FR3: Unique QR generation per course (saving the course data)
  Future<int> createCourse(String name, double lat, double long, double rad) async {
    final db = await instance.database;
    return await db.insert('courses', {
      'courseName': name,
      'latitude': lat,
      'longitude': long,
      'radius': rad
    });
  }

  // FR7: Record student info + timestamp
  Future<int> markAttendance(int courseId, String student, bool isValid) async {
    final db = await instance.database;
    return await db.insert('attendance', {
      'courseId': courseId,
      'studentName': student,
      'checkInTime': DateTime.now().toIso8601String(),
      'isValid': isValid ? 1 : 0 // 1 = Present, 0 = Denied (Outside Geofence)
    });
  }
}