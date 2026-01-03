import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ScanProgressPage extends StatefulWidget {
  final String targetUrl;
  final List<String> logMessages;

  const ScanProgressPage({
    Key? key,
    required this.targetUrl,
    required this.logMessages,
  }) : super(key: key);

  @override
  _ScanProgressPageState createState() => _ScanProgressPageState();
}

class _ScanProgressPageState extends State<ScanProgressPage>
    with SingleTickerProviderStateMixin {
  double progress = 0.0;
  List<String> scanActivities = [];
  int currentActivity = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isScanning = true;
  Map<String, dynamic>? scanData;
  List<String> _logMessages = [];
  final StreamController<List<String>> _logController =
      StreamController<List<String>>.broadcast();

  // Common endpoints to try
  List<String> get _endpoints => [
        "http://10.0.2.2:5000",
        "http://127.0.0.1:5000",
        "http://localhost:5000",
      ];

  @override
  void initState() {
    super.initState();

    // Initialize with passed log messages
    _logMessages = List.from(widget.logMessages);

    // Animation controller for circular scanning effect
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _performScan();
    _simulateProgress();
  }

  @override
  void dispose() {
    _controller.dispose();
    _logController.close();
    super.dispose();
  }

  void _addLogMessage(String message) {
    setState(() {
      _logMessages
          .add("${DateTime.now().toString().substring(11, 19)} $message");
      _logController.add(_logMessages);
      scanActivities.add(message);
    });
  }

  Future<void> _performScan() async {
    _addLogMessage("🚀 Starting scan for: ${widget.targetUrl}");
    _addLogMessage("🔧 Initializing vulnerability scanners...");

    try {
      http.Response? response;
      String? lastError;

      for (var baseUrl in _endpoints) {
        try {
          final endpoint = "$baseUrl/scan";
          _addLogMessage("🔗 Trying to connect to: $endpoint");

          response = await http
              .post(
                Uri.parse(endpoint),
                headers: {"Content-Type": "application/json"},
                body: json.encode({"url": widget.targetUrl}),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            _addLogMessage("✅ Connected successfully to scanner API");
            setState(() {
              scanData = json.decode(response!.body);
              _addLogMessage("🎉 Scan completed successfully!");
              _isScanning = false;
              progress = 1.0;
            });
            break;
          } else {
            lastError =
                "Server responded with status code: ${response.statusCode}";
            _addLogMessage("❌ Server error: $lastError");
          }
        } catch (e) {
          lastError = e.toString();
          _addLogMessage("❌ Connection failed: ${e.toString()}");
          continue;
        }
      }

      if (response == null || response.statusCode != 200) {
        setState(() {
          scanData = {
            "error": "Unable to connect to scanner: ${lastError ?? 'Unknown error'}"
          };
          _addLogMessage("💥 Failed to connect to scanner API");
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        scanData = {
          "error": "❌ Failed to connect to the scanner API: ${e.toString()}"
        };
        _addLogMessage("💥 Critical error: ${e.toString()}");
        _isScanning = false;
      });
    }
  }

  void _simulateProgress() async {
    for (int i = 1; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() {
        progress = i / 100;
        if (i % 8 == 0 && currentActivity < scanActivities.length - 1) {
          currentActivity++;
        }
      });
    }
  }

  // Navigation functions
  void _navigateToHome() {
    Navigator.pushNamed(context, '/');
  }

  void _navigateToProgress() {
    // Already on progress page
  }

  void _navigateToResults() {
    if (scanData != null) {
      Navigator.pushNamed(
        context,
        '/results',
        arguments: {
          'scanData': scanData,
          'logs': _logMessages,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results not available yet')),
      );
    }
  }

  void _navigateToReports() {
    if (scanData != null) {
      Navigator.pushNamed(
        context,
        '/reports',
        arguments: {
          'scanData': scanData,
          'logs': _logMessages,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No scan data available yet')),
      );
    }
  }

  Color _getRiskColor(String type) {
    if (type.contains("SQL Injection") ||
        type.contains("XSS") ||
        type.contains("High")) {
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
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: vulns.isEmpty ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Chip(
              label: Text("${vulns.length} found",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: vulns.isEmpty ? Colors.green : Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        vulns.isEmpty
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
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
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
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
                            Icon(Icons.warning,
                                color: _getRiskColor(severity), size: 16),
                            const SizedBox(width: 8),
                            Text("$type - $severity",
                                style: TextStyle(
                                    color: _getRiskColor(severity),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Payload: $payload",
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text("Form: $formAction",
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildAIAnalysisSection(dynamic aiAnalysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
            SizedBox(width: 8),
            Text("🤖 AI Security Analysis",
                style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (aiAnalysis is List)
          ...aiAnalysis.map<Widget>((analysis) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
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
                      Icon(Icons.warning,
                          color: _getRiskColor(analysis["severity"] ?? "Info"),
                          size: 16),
                      const SizedBox(width: 8),
                      Text("${analysis["vulnerability_type"]} - ${analysis["severity"]}",
                          style: TextStyle(
                              color: _getRiskColor(analysis["severity"] ?? "Info"),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("${analysis["description"]}",
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text("Recommendation: ${analysis["recommendation"]}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        if (aiAnalysis is String && aiAnalysis.contains("Gemini analysis failed"))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("❌ AI analysis unavailable: $aiAnalysis",
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultsCard() {
    if (scanData == null) return Container();

    final sqliVulns = scanData!["sqli_vulnerabilities"] is List ? scanData!["sqli_vulnerabilities"] : [];
    final xssVulns = scanData!["xss_vulnerabilities"] is List ? scanData!["xss_vulnerabilities"] : [];
    final cmdiVulns = scanData!["command_injection_vulnerabilities"] is List ? scanData!["command_injection_vulnerabilities"] : [];
    final lfiVulns = scanData!["lfi_vulnerabilities"] is List ? scanData!["lfi_vulnerabilities"] : [];
    final aiAnalysis = scanData!["ai_analysis"];
    final url = scanData!["url"] ?? "Unknown URL";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.greenAccent, size: 24),
              const SizedBox(width: 8),
              const Text("Scan Results",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const Chip(
                label: Text("Completed", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text("Scanned URL: $url",
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          _buildVulnerabilityList("SQL Injection", sqliVulns),
          const SizedBox(height: 15),
          _buildVulnerabilityList("XSS Vulnerabilities", xssVulns),
          const SizedBox(height: 15),
          _buildVulnerabilityList("Command Injection", cmdiVulns),
          const SizedBox(height: 15),
          _buildVulnerabilityList("Local File Inclusion", lfiVulns),
          const SizedBox(height: 20),
          if (aiAnalysis != null) _buildAIAnalysisSection(aiAnalysis),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: scanData == null ? null : _navigateToResults,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_forward, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "View Summary",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, String value, double progressValue,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: TextStyle(
                color: isBold ? Colors.green : Colors.white,
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.grey,
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF161B22),
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0D1117)),
            child: Row(
              children: const [
                Icon(Icons.security, color: Colors.blueAccent, size: 28),
                SizedBox(width: 8),
                Text("VulScanner",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.white),
            title: const Text("Dashboard", style: TextStyle(color: Colors.white)),
            onTap: _navigateToHome,
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.white),
            title: const Text("Scan History", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.white),
            title: const Text("User Communication", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text("Settings", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavItem(String title, bool isActive, VoidCallback onPressed) {
    return Container(
      decoration: isActive
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.blue, width: 2)),
            )
          : null,
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
              color: const Color(0xFF161B22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.security,
                          color: Color.fromARGB(255, 10, 137, 255)),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 1),
                    const Text("VulScanner",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    _buildTopNavItem("Home", false, _navigateToHome),
                    _buildTopNavItem("Progress", true, _navigateToProgress),
                    _buildTopNavItem("Results", false, _navigateToResults),
                    _buildTopNavItem("Reports", false, _navigateToReports),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: Text(
                                  "AI-Forward Vulnerability Assessment",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "AI Scan Progress",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 150,
                                      height: 150,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 10,
                                        backgroundColor: Colors.grey,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.blueAccent),
                                      ),
                                    ),
                                    AnimatedBuilder(
                                      animation: _animation,
                                      builder: (context, child) {
                                        return SizedBox(
                                          width: 200,
                                          height: 200,
                                          child: CustomPaint(
                                            painter: _CircularScanPainter(
                                              progress: progress,
                                              scanValue: _animation.value,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${(progress * 100).toStringAsFixed(0)}%",
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          "Complete",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildProgressItem("Pages Crawled", "Scanning", 1.0,isBold: true),
                              _buildProgressItem("Forms Found", "Scanning", 1.0,isBold: true),
                              _buildProgressItem("AI Analysis", "Scanning", 1.0,
                                  isBold: true),
                              _buildProgressItem("Vulnerabilities", "Scanning", 1.0,isBold: true),
                              const SizedBox(height: 20),
                              Divider(color: Colors.grey),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      "Pause Scan",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      "Stop Scan",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
  flex: 1,
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black, // outer container color
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Live Scanning Logs",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 300,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[850], // inner container gray color
            borderRadius: BorderRadius.circular(8),
          ),
          child: StreamBuilder<List<String>>(
            stream: _logController.stream,
            initialData: _logMessages,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              return ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                      logs[index],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontFamily: 'Monospace',
                      ),
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
),

                    ],
                  ),
                  const SizedBox(height: 20),
                  if (scanData != null) _buildResultsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularScanPainter extends CustomPainter {
  final double progress;
  final double scanValue;

  _CircularScanPainter({required this.progress, required this.scanValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 3.14 * 2,
      colors: [
        Colors.transparent,
        Colors.blueAccent.withOpacity(0.7),
        const Color.fromARGB(255, 0, 174, 255),
        const Color.fromARGB(0, 19, 6, 6),
      ],
      stops: [0.0, scanValue, scanValue + 0.1, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      6.28 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularScanPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.scanValue != scanValue;
  }
}