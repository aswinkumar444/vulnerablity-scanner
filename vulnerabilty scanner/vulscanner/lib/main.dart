import 'package:flutter/material.dart';
import 'package:vulscanner/docker.dart';
import 'package:vulscanner/dos.dart';
import 'package:vulscanner/home_page.dart';
import 'package:vulscanner/reportpage.dart';
import 'package:vulscanner/result.dart';
import 'package:vulscanner/scan_progress_page.dart';
import 'package:vulscanner/sens.dart';
void main() {
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Web Vulnerability Scanner',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.purpleAccent,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/progress': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?; // null-safe
          return ScanProgressPage(
            targetUrl: args?['targetUrl'],
            logMessages: args?['logMessages'],
          );
        },
        '/results': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?; // null-safe
          return ResultsPage(
            scanData: args?['scanData'],
            logs: args?['logs'],
          );
        },
        '/reports': (context) => ReportExportPage(),
        '/docker': (context) => FileUploadPage(),
        '/dos': (context) => const DoSHomePage(),
         '/sens': (context) => const SensitiveDetectionPage(), // Add DoS route
      },
    );
  }
}