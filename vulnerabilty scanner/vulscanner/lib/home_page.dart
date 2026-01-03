import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
//
import 'scan_progress_page.dart';
class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedScanType = "Quick Scan (1 min)";
  bool _isScanning = false;
  Map<String, dynamic>? scanData;
  String _connectionStatus = "Ready to scan";
  List<String> _logMessages = [];
  StreamController<List<String>> _logController = StreamController<List<String>>.broadcast();
  bool _isConnected = false;

  List<String> get _endpoints => [
        "http://10.0.2.2:5000",
        "http://127.0.0.1:5000",
        "http://localhost:5000",
      ];
  Future<void> _testConnection() async {
    bool connected = false;
    String lastError = "";
    for (var baseUrl in _endpoints) {
      try {
        final response = await http
            .get(Uri.parse("$baseUrl/health"))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          connected = true;
          break;
        } else {
          lastError = "Server responded with status code: ${response.statusCode}";
        }
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }
    setState(() {
      _isConnected = connected;
      _connectionStatus = connected ? "Connected to scanner" : "Scanner not connected - $lastError";
    });
  }
  Future<void> startScan() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠ Please enter a valid URL")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanProgressPage(
          targetUrl: _urlController.text,
          logMessages: List.from(_logMessages),
        ),
      ),
    );
    setState(() {
      _logMessages.clear();
    });
  }
  void _addLogMessage(String message) {
    setState(() {
      _logMessages.add("${DateTime.now().toString().substring(11, 19)} $message");
      _logController.add(_logMessages);
    });
  }
  Color _getRiskColor(String type) {
    if (type.contains("SQL Injection") || type.contains("XSS") || type.contains("High")) {
      return Colors.redAccent;
    } else if (type.contains("Medium")) {
      return Colors.orangeAccent;
    } else if (type.contains("Low")) {
      return Colors.yellowAccent;
    } else if (type.contains("Info")) {
      return Colors.blueAccent;
    }
    return Colors.greenAccent;
  }

  Color _getLogColor(String message) {
    if (message.contains("❌") || message.contains("💥") || message.contains("failed")) {
      return const Color.fromARGB(255, 255, 255, 255);
    } else if (message.contains("⚠") || message.contains("warning")) {
      return Colors.orangeAccent;
    } else if (message.contains("✅") || message.contains("success")) {
      return Colors.greenAccent;
    } else if (message.contains("🔍") || message.contains("testing")) {
      return Colors.blueAccent;
    } else if (message.contains("🤖") || message.contains("AI")) {
      return Colors.purpleAccent;
    }
    return Colors.white70;
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testConnection();
    });
  }
  @override
  void dispose() {
    _logController.close();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D1117),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Color(0xFF161B22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    Icon(Icons.security, color: Colors.blueAccent, size: 28),
                    SizedBox(width: 5),
                    Text(
                      "VulScanner",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildTopNavItem("Home", true, _navigateToHome),
                    _buildTopNavItem("Progress", false, _navigateToProgress),
                    _buildTopNavItem("Results", false, _navigateToResults),
                    _buildTopNavItem("Reports", false, _navigateToReports),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  Text(
                    "Advanced WebSec Scanner",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "AI-powered scanning, real-time analytics, and developer education\nto secure modern web applications.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.warning,
                          color: _isConnected ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _connectionStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.refresh, size: 18),
                          color: Colors.white70,
                          onPressed: _isScanning ? null : _testConnection,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: 600,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _urlController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Target URL",
                            labelStyle: TextStyle(color: Colors.white70),
                            hintText: "https://example.com or http://localhost:8000",
                            hintStyle: TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF0D1117),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isScanning ? null : startScan,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: _isConnected ? Colors.blueAccent : Colors.grey,
                          ),
                          child: _isScanning
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    SizedBox(width: 10),
                                    Text("Scanning...", style: TextStyle(color: Colors.white)),
                                  ],
                                )
                              : Text(
                                  "🔍 Start Scan",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Try: http://localhost:8000 or https://example.com",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  if (_isScanning || _logMessages.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.list_alt, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Live Scan Logs",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: StreamBuilder<List<String>>(
                              stream: _logController.stream,
                              initialData: _logMessages,
                              builder: (context, snapshot) {
                                final logs = snapshot.data ?? [];
                                return ListView.builder(
                                  padding: EdgeInsets.all(8),
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) {
                                    return Text(
                                      logs[index],
                                      style: TextStyle(
                                        color: _getLogColor(logs[index]),
                                        fontSize: 12,
                                        fontFamily: 'Monospace',
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 20),
                  scanData == null
                      ? Container()
                      : scanData!.containsKey("error")
                          ? _buildErrorCard(scanData!["error"])
                          : _buildResultsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushNamed(context, '/');
  }

  void _navigateToProgress() {}

  void _navigateToResults() {
    Navigator.pushNamed(context, '/results');
  }

  void _navigateToReports() {
    Navigator.pushNamed(context, '/reports');
  }
  Widget _buildResultsCard() {
    final sqliVulns = scanData?["sqli_vulnerabilities"] is List ? scanData!["sqli_vulnerabilities"] : [];
    final xssVulns = scanData?["xss_vulnerabilities"] is List ? scanData!["xss_vulnerabilities"] : [];
    final cmdiVulns = scanData?["command_injection_vulnerabilities"] is List ? scanData!["command_injection_vulnerabilities"] : [];
    final lfiVulns = scanData?["lfi_vulnerabilities"] is List ? scanData!["lfi_vulnerabilities"] : [];
    final aiAnalysis = scanData?["ai_analysis"];
    final url = scanData?["url"] ?? "Unknown URL";
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.greenAccent, size: 24),
              SizedBox(width: 8),
              Text("Scan Results",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Spacer(),
              Chip(
                label: Text("Completed", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
              ),
            ],
          ),
          SizedBox(height: 15),
          Text("Scanned URL: $url", style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(height: 20),
          _buildVulnerabilityList("SQL Injection", sqliVulns),
          SizedBox(height: 15),
          _buildVulnerabilityList("XSS Vulnerabilities", xssVulns),
          SizedBox(height: 15),
          _buildVulnerabilityList("Command Injection", cmdiVulns),
          SizedBox(height: 15),
          _buildVulnerabilityList("Local File Inclusion", lfiVulns),
          SizedBox(height: 20),
          if (aiAnalysis != null) _buildAIAnalysisSection(aiAnalysis),
        ],
      ),
    );
  }
  Widget _buildAIAnalysisSection(dynamic aiAnalysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
            SizedBox(width: 8),
            Text("🤖 AI Security Analysis",
                style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 12),
        if (aiAnalysis is List)
          ...aiAnalysis.map<Widget>((analysis) {
            return Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRiskColor(analysis["severity"] ?? "Info").withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getRiskColor(analysis["severity"] ?? "Info"),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: _getRiskColor(analysis["severity"] ?? "Info"), size: 16),
                      SizedBox(width: 8),
                      Text("${analysis["vulnerability_type"]} - ${analysis["severity"]}",
                          style: TextStyle(
                              color: _getRiskColor(analysis["severity"] ?? "Info"),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text("${analysis["description"]}", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 6),
                  Text("Recommendation: ${analysis["recommendation"]}",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        if (aiAnalysis is String && aiAnalysis.contains("Gemini analysis failed"))
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text("❌ AI analysis unavailable: $aiAnalysis",
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVulnerabilityList(String title, List<dynamic> vulns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              vulns.isEmpty ? Icons.check_circle : Icons.warning,
              color: vulns.isEmpty ? Colors.greenAccent : Colors.orangeAccent,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: vulns.isEmpty ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Chip(
              label: Text("${vulns.length} found", style: TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: vulns.isEmpty ? Colors.green : Colors.orange,
            ),
          ],
        ),
        SizedBox(height: 8),
        vulns.isEmpty
            ? Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text("✅ No vulnerabilities found",
                        style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                  ],
                ),
              )
            : Column(
                children: vulns.map((vuln) {
                  final type = vuln is Map ? vuln["type"]?.toString() ?? "Unknown" : "Unknown";
                  final payload = vuln is Map ? vuln["payload"]?.toString() ?? "Unknown" : "Unknown";
                  final formAction = vuln is Map ? vuln["form_action"]?.toString() ?? "Unknown" : "Unknown";
                  final severity = vuln is Map ? vuln["severity"]?.toString() ?? "Medium" : "Medium";
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getRiskColor(severity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getRiskColor(severity),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: _getRiskColor(severity), size: 16),
                            SizedBox(width: 8),
                            Text("$type - $severity",
                                style: TextStyle(
                                    color: _getRiskColor(severity),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text("Payload: $payload", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        SizedBox(height: 4),
                        Text("Form: $formAction", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }
  Widget _buildErrorCard(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ),
        ],
      ),
    );
  }
  Widget _buildTopNavItem(String title, bool isActive, VoidCallback onPressed) {
    return Container(
      decoration: isActive ? BoxDecoration(border: Border(bottom: BorderSide(color: Colors.blue, width: 2))) : null,
      child: TextButton(
        onPressed: onPressed,
        child: Text(title,
            style: TextStyle(
              color: isActive ? Colors.blueAccent : Colors.grey,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Color(0xFF161B22),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF0D1117)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.blueAccent, size: 32),
                    SizedBox(width: 12),
                    Text(
                      "VulScanner",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text("AI-Powered Security Scanner", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: const Color.fromARGB(255, 125, 247, 81)),
            title: Text("Dashboard", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.history, color: const Color.fromARGB(255, 200, 106, 106)),
            title: Text("Scan History", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.auto_awesome, color: Colors.purpleAccent),
            title: Text("Sensitive-Data", style: TextStyle(color: Colors.white)),
            onTap: () {
               Navigator.pushNamed(context, '/sens');
            },
          ),
          ListTile(
            leading: Icon(Icons.electrical_services, color: const Color.fromARGB(255, 67, 10, 252)),
            title: Text("DOS-Attack", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushNamed(context, '/dos');
            },
          ),
               ListTile(
            leading: Icon(Icons.security_update_good_sharp, color: Colors.blueAccent),
            title: Text("Docker", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushNamed(context, '/docker');
            },
          ),
          Divider(color: Colors.grey.shade700),
          ListTile(
            leading: Icon(Icons.info, color: const Color.fromARGB(255, 69, 95, 242)),
            title: Text("About", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          Divider(color: Colors.grey.shade700),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}