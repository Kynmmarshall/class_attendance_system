
import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/services/geofencing.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StudentScanScreen extends StatefulWidget {
  @override
  _StudentScanScreenState createState() => _StudentScanScreenState();
}

class _StudentScanScreenState extends State<StudentScanScreen> {
  final GeofenceService _geoService = GeofenceService();

  void _handleScan(String rawData) async {
    // 1. Parse QR Data (Simple parsing for prototype)
    // Format: "CourseID:101,Lat:3.8480,Long:11.5021,Rad:50"
    try {
      final parts = rawData.split(',');
      double targetLat = double.parse(parts[1].split(':')[1]);
      double targetLong = double.parse(parts[2].split(':')[1]);
      double radius = double.parse(parts[3].split(':')[1]);

      // 2. Verify Geofence [cite: 28]
      bool inRange = await _geoService.isStudentInRange(targetLat, targetLong, radius);

      // 3. Log to Local SQL
      await DatabaseHelper.instance.markAttendance(
        101, 
        "Student User", 
        inRange
      );

      // 4. Show Result
      if (inRange) {
        _showDialog("Success", "Attendance Marked! You are in class.");
      } else {
        _showDialog("Access Denied", "You are outside the classroom boundary. ");
      }
    } catch (e) {
      _showDialog("Error", "Invalid QR Code");
    }
  }

  void _showDialog(String title, String msg) {
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(title: Text(title), content: Text(msg))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan QR")),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
             if (barcode.rawValue != null) {
               _handleScan(barcode.rawValue!);
               break; // Stop after first scan
             }
          }
        },
      ),
    );
  }
}