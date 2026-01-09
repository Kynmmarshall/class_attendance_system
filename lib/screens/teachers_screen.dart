// --- TEACHER SCREEN (Generates QR) ---
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeacherScreen extends StatelessWidget {
  // Hardcoded for prototype: The ICT University location or similar
  final double dummyLat = 3.8480; 
  final double dummyLong = 11.5021; 

  @override
  Widget build(BuildContext context) {
    // The QR data embeds the Course ID and expected Location coordinates
    // In a real app, this data comes from the DB.
    String qrData = "CourseID:101,Lat:$dummyLat,Long:$dummyLong,Rad:50";

    return Scaffold(
      appBar: AppBar(title: Text("Course QR Code")),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 50),
            Text("Scan this to mark attendance for ICT 101"),
            SizedBox(height: 20),
            QrImageView(
              data: qrData, // [cite: 12] Unique Code per course
              version: QrVersions.auto,
              size: 200.0,
            ),
          ],
        ),
      ),
    );
  }
}