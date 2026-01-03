import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class FileUploadPage extends StatefulWidget {
  const FileUploadPage({super.key});

  @override
  State<FileUploadPage> createState() => _FileUploadPageState();
}

class _FileUploadPageState extends State<FileUploadPage> {
  List<Map<String, dynamic>> scannedFiles = [];

  final String backendBase = "http://127.0.0.1:5001";

  Future<void> uploadAndScanFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar("⚠ No file selected");
        return;
      }

      final pickedFile = result.files.single;
      final fileBytes = pickedFile.bytes;
      final fileName = pickedFile.name;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$backendBase/scan_file"),
      );

      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ));
      } else if (pickedFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          pickedFile.path!,
        ));
      } else {
        _showSnackBar("❌ Could not read file");
        return;
      }

      final response = await request.send();
      final respData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(respData);
        setState(() {
          scannedFiles.add(Map<String, dynamic>.from(jsonData));
        });
        _showSnackBar("✅ File scanned successfully");
      } else {
        _showSnackBar("❌ Failed: $respData");
      }
    } catch (e) {
      _showSnackBar("⚠ Error: $e");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // main background
      appBar: AppBar(
        title: const Text(
          "File Upload & Scan",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: Column(
        children: [
        
          Expanded(
            flex: 2,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: uploadAndScanFile,
                icon: const Icon(
                  Icons.upload_file,
                  size: 40, 
                  color: Colors.white,
                ),
                label: const Text(
                  "Upload & Scan File",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 25,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.blueAccent.withOpacity(0.5),
                ),
              ),
            ),
          ),

         
          Expanded(
            flex: 3,
            child: scannedFiles.isNotEmpty
                ? ListView.builder(
                    itemCount: scannedFiles.length,
                    itemBuilder: (context, index) {
                      final f = scannedFiles[index];
                      return Card(
                        color: const Color(0xFF161B22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            f["name"],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                "Status: ${f["status"]} • Severity: ${f["severity"]}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: f["status"] == "RISK"
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "MD5: ${f["hash"]}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      "No files scanned yet.",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}