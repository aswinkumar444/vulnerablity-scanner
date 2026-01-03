import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
class SensitiveDetectionPage extends StatefulWidget {
  const SensitiveDetectionPage({Key? key}) : super(key: key);

  @override
  State<SensitiveDetectionPage> createState() => _SensitiveDetectionPageState();
}
class _SensitiveDetectionPageState extends State<SensitiveDetectionPage> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  bool _loading = false;
  bool _serverConnected = false;
  final String baseUrl = 'http://127.0.0.1:5004'; 
  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }
  Future<void> _checkServerConnection() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() => _serverConnected = true);
      } else {
        setState(() => _serverConnected = false);
      }
    } catch (e) {
      print('Server connection error: $e');
      setState(() => _serverConnected = false);
    }
  }
  Future<void> detectSensitive(String text) async {
    if (text.trim().isEmpty) {
      setState(() => _result = 'Please enter text');
      return;
    }
    if (!_serverConnected) {
      setState(() => _result = 'Server not connected. Please check your connection.');
      return;
    }
    setState(() {
      _loading = true;
      _result = '';
    });
    try {
      final url = Uri.parse('$baseUrl/detect');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data.containsKey('error')) {
          setState(() => _result = 'Error: ${data['error']}');
          return;
        }
        
        final sensitive = (data['sensitive'] as num).toInt();
        final prob = (data['probability'] as num?)?.toDouble();
        final method = data['method'] as String?;
        
        setState(() {
          if (sensitive == 1) {
            _result = 'Sensitive (${method == 'exact_match' ? 'exact match' : 'AI detected'}, confidence: ${(prob! * 100).toStringAsFixed(1)}%)';
          } else {
            _result = 'Not sensitive (${method == 'exact_match' ? 'exact match' : 'AI detected'}, confidence: ${(prob! * 100).toStringAsFixed(1)}%)';
          }
        });
      } else {
        setState(() => _result = 'Error: ${response.statusCode} ${response.body}');
      }
    } on SocketException {
      setState(() => _result = 'Network error: Cannot connect to server. Make sure the server is running.');
    } on http.ClientException {
      setState(() => _result = 'Network error: Cannot connect to server. Check your connection.');
    } catch (e) {
      print('Detailed error: $e');
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensitive Detection')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter text',
                border: OutlineInputBorder(),
                hintText: 'Type text to check for sensitive content',
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => detectSensitive(_controller.text),
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Check Sensitivity'),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.circle,
                  color: _serverConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  _serverConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _serverConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_result.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result.contains('Sensitive') ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _result.contains('Sensitive') ? Colors.red : Colors.green,
                    width: 2,
                  ),
                ),
                child: Text(
                  _result,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _result.contains('Sensitive') ? Colors.red.shade800 : Colors.green.shade800,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}