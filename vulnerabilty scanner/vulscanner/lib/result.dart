import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
class VulnSummary {
  final int manualTotal;
  final int sqli;
  final int xss;
  final int cmdi;
  final int lfi;
  final int critical;
  final int high;
  final int medium;
  final int low;
  final List<Map<String, String>> aiItems;

  VulnSummary({
    required this.manualTotal,
    required this.sqli,
    required this.xss,
    required this.cmdi,
    required this.lfi,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
    required this.aiItems,
  });

  int get aiTotal => critical + high + medium + low;
  int get combinedTotal => manualTotal + aiTotal;
}

String normalizeSeverity(String? s) {
  final v = (s ?? '').toLowerCase();
  if (v.contains('critical')) return 'Critical';
  if (v.contains('high')) return 'High';
  if (v.contains('medium')) return 'Medium';
  if (v.contains('low')) return 'Low';
  return 'Low';
}

VulnSummary buildSummary(Map<String, dynamic> scanData) {
  final List sqli = (scanData['sqli_vulnerabilities'] is List) ? (scanData['sqli_vulnerabilities'] as List) : const [];
  final List xss = (scanData['xss_vulnerabilities'] is List) ? (scanData['xss_vulnerabilities'] as List) : const [];
  final List cmdi = (scanData['command_injection_vulnerabilities'] is List) ? (scanData['command_injection_vulnerabilities'] as List) : const [];
  final List lfi = (scanData['lfi_vulnerabilities'] is List) ? (scanData['lfi_vulnerabilities'] as List) : const [];

  int critical = 0, high = 0, medium = 0, low = 0;

  final manualTotal = sqli.length + xss.length + cmdi.length + lfi.length;

  final ai = scanData['ai_analysis'];
  final List<Map<String, String>> aiItems = [];

  if (ai is List) {
    for (final it in ai) {
      if (it is Map) {
        final sev = normalizeSeverity(it['severity']?.toString());
        if (sev == 'Critical') critical++;
        else if (sev == 'High') high++;
        else if (sev == 'Medium') medium++;
        else low++;
        aiItems.add({
          'type': (it['vulnerability_type'] ?? 'AI Finding').toString(),
          'severity': sev,
          'description': (it['description'] ?? '').toString(),
          'recommendation': (it['recommendation'] ?? '').toString(),
        });
      }
    }
  } else if (ai is String && ai.isNotEmpty) {
    low++;
    aiItems.add({
      'type': 'AI Analysis',
      'severity': 'Low',
      'description': ai.toString(),
      'recommendation': '',
    });
  }
  return VulnSummary(
    manualTotal: manualTotal,
    sqli: sqli.length,
    xss: xss.length,
    cmdi: cmdi.length,
    lfi: lfi.length,
    critical: critical,
    high: high,
    medium: medium,
    low: low,
    aiItems: aiItems,
  );
}
const Color kBg = Color(0xFF0D1117);
const Color kSurface = Color(0xFF141A22);
const Color kSurfaceAlt = Color(0xFF10161D);
const Color kBorder = Color(0xFF2E3440);

const Color kText = Color(0xFFE6EAF0);
const Color kTextSubtle = Color(0xFFAAB2BE);

const Color kBlue = Color(0xFF5BA2F8);
const Color kTeal = Color(0xFF33C2B6);
const Color kPurple = Color(0xFFA789F5);
const Color kPink = Color(0xFFF063A7);
const Color kAmber = Color(0xFFF3B43F);
const Color kGreen = Color(0xFF2FCF7F);

const Color kCritical = Color(0xFFE45C5C);
const Color kHigh = Color(0xFFF08A1F);
const Color kMedium = Color(0xFFD9B814);
const Color kLow = Color(0xFF5C9DF2);

List<Color> tileGradBlue = const [Color(0xFF0E1B2B), Color(0xFF0A1623)];
List<Color> tileGradTeal = const [Color(0xFF0B201F), Color(0xFF081917)];
List<Color> tileGradPurple = const [Color(0xFF1A1428), Color(0xFF130E20)];
List<Color> tileGradCritical = const [Color(0xFF241116), Color(0xFF1B0C10)];
List<Color> tileGradHigh = const [Color(0xFF22190E), Color(0xFF1A120A)];
List<Color> tileGradMedium = const [Color(0xFF1F1B0E), Color(0xFF171309)];
List<Color> tileGradLow = const [Color(0xFF0D1B2A), Color(0xFF0A1521)];

List<Color> aiCardGrad(String sev) {
  switch (sev) {
    case 'Critical':
      return [const Color(0xFF28151A), const Color(0xFF1E0F13)];
    case 'High':
      return [const Color(0xFF231B10), const Color(0xFF1B140C)];
    case 'Medium':
      return [const Color(0xFF211D10), const Color(0xFF19140B)];
    default:
      return [const Color(0xFF102338), const Color(0xFF0C1D2E)];
  }
}
Color sevPillColor(String sev) {
  switch (sev) {
    case 'Critical':
      return kCritical;
    case 'High':
      return kHigh;
    case 'Medium':
      return kMedium;
    default:
      return kLow;
  }
}
class ResultsPage extends StatefulWidget {
  final Map<String, dynamic>? scanData;
  final List<String>? logs;
  const ResultsPage({Key? key, this.scanData, this.logs}) : super(key: key);

  @override
  _ResultsPageState createState() => _ResultsPageState();
}
class _ResultsPageState extends State<ResultsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool showCritical = true;
  bool showHigh = true;
  bool showMedium = true;
  bool showLow = true;

  late Map<String, dynamic>? _scanData; 
  late List<String>? _logs; 
  VulnSummary? _summary; 
  String _url = 'Unknown URL'; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _computeData();
    });
  }

  void _computeData() {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic>? argMap = (routeArgs is Map<String, dynamic>) ? routeArgs : null;

    _scanData = widget.scanData ?? argMap?['scanData'] as Map<String, dynamic>?;
    _logs = widget.logs ?? (argMap != null && argMap['logs'] is List ? List<String>.from(argMap['logs'] as List) : null);

    print('ResultsPage computed _scanData: $_scanData');
    print('ResultsPage widget.scanData: ${widget.scanData}');
    print('ResultsPage argMap: $argMap');
    print('ResultsPage computed _logs: $_logs');

    _url = _scanData?['url']?.toString() ?? 'Unknown URL';
    _summary = _scanData != null ? buildSummary(_scanData!) : null;
    print('ResultsPage computed _summary: $_summary');

    if (mounted) setState(() {}); 
  }
  void _navigateToHome() => Navigator.pushNamed(context, '/');
  void _navigateToProgress() => Navigator.pushNamed(context, '/progress');

  void _navigateToResults() {
    Navigator.pushNamed(
      context,
      '/result',
      arguments: {
        'scanData': _scanData,
        'logs': _logs,
      },
    );
  }

  void _navigateToReports() {
    Navigator.pushNamed(
      context,
      '/reports',
      arguments: {
        'scanData': _scanData,
        'logs': _logs,
      },
    );
  }
  Widget _statTile({
    required String title,
    required String value,
    required List<Color> gradient,
    required IconData icon,
    double? height,
  }) {
    final h = height ?? 130;
    return Container(
      height: h,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kSurfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, color: kText, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: kTextSubtle, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(color: kText, fontSize: 34, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _metricPill(String label, String value, Color color, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kSurfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            child: Text(value, style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
  Widget _aiCard(Map<String, String> it) {
    final sev = it['severity'] ?? 'Low';
    final grad = aiCardGrad(sev);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: const [
              Icon(Icons.shield, size: 16, color: kText),
              SizedBox(width: 6),
              Text("AI Finding", style: TextStyle(color: kText, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: sevPillColor(sev)),
            ),
            child: Row(children: [
              Icon(Icons.circle, size: 10, color: sevPillColor(sev)),
              const SizedBox(width: 6),
              Text(sev, style: const TextStyle(color: kText, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(it['description'] ?? '', style: const TextStyle(color: kText, fontSize: 14, height: 1.5)),
        if ((it['recommendation'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.tips_and_updates, size: 18, color: kTextSubtle),
            const SizedBox(width: 8),
            Expanded(child: Text(it['recommendation'] ?? '', style: const TextStyle(color: kTextSubtle, fontSize: 13, height: 1.5))),
          ]),
        ],
      ]),
    );
  }

  Widget _aiFilterPill(String label, bool value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? kSurface : kSurfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: value ? color : kBorder),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _findingsPanel(VulnSummary summary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Findings by category", style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricPill("SQL Injection", "${summary.sqli}", kCritical, Icons.storage),
            _metricPill("XSS", "${summary.xss}", kHigh, Icons.code),
            _metricPill("Command Injection", "${summary.cmdi}", kPurple, Icons.terminal),
            _metricPill("LFI", "${summary.lfi}", kTeal, Icons.insert_drive_file),
          ],
        ),
      ]),
    );
  }
  Widget _vulnerabilityPieChart(VulnSummary summary) {
    final total = summary.combinedTotal;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: const Center(
          child: Text(
            "No vulnerabilities detected",
            style: TextStyle(color: kTextSubtle, fontSize: 16),
          ),
        ),
      );
    }
    final pieSections = <PieChartSectionData>[
      PieChartSectionData(
        value: summary.sqli.toDouble(),
        color: kCritical,
        title: 'SQLi: ${summary.sqli}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.xss.toDouble(),
        color: kHigh,
        title: 'XSS: ${summary.xss}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.cmdi.toDouble(),
        color: kPurple,
        title: 'CMDi: ${summary.cmdi}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.lfi.toDouble(),
        color: kTeal,
        title: 'LFI: ${summary.lfi}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.critical.toDouble(),
        color: kCritical.withOpacity(0.8),
        title: 'Critical (AI): ${summary.critical}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.high.toDouble(),
        color: kHigh.withOpacity(0.8),
        title: 'High (AI): ${summary.high}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.medium.toDouble(),
        color: kMedium.withOpacity(0.8),
        title: 'Medium (AI): ${summary.medium}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
      PieChartSectionData(
        value: summary.low.toDouble(),
        color: kLow.withOpacity(0.8),
        title: 'Low (AI): ${summary.low}',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
      ),
    ].where((section) => section.value > 0).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vulnerability Distribution",
            style: TextStyle(
              color: kText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sections: pieSections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vulnerabilityDistributionOverTime(VulnSummary summary) {
    final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7', 'Week 8'];
    final injectionData = [4.0, 3.0, 5.0, 2.0, 1.0, 2.0, 1.0, 2.0];
    final xssData = [7.0, 6.0, 8.0, 5.0, 4.0, 6.0, 3.0, 5.0];
    final authData = [2.0, 3.0, 1.0, 4.0, 2.0, 1.0, 3.0, 2.0];
    final configData = [11.0, 9.0, 13.0, 7.0, 8.0, 10.0, 6.0, 7.0];

    List<FlSpot> _mapData(List<double> data) =>
        List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vulnerability Distribution Over Time",
            style: TextStyle(
              color: kText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 14,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < weeks.length) {
                          return Text(
                            weeks[index],
                            style: const TextStyle(color: kTextSubtle, fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: kTextSubtle, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 2,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(color: kBorder, strokeWidth: 0.5),
                  getDrawingVerticalLine: (value) => FlLine(color: kBorder, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _mapData(injectionData),
                    isCurved: true,
                    color: kCritical,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: _mapData(xssData),
                    isCurved: true,
                    color: kHigh,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: _mapData(authData),
                    isCurved: true,
                    color: kPurple,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                    barWidth: 3,
                  ),
                  LineChartBarData(
                    spots: _mapData(configData),
                    isCurved: true,
                    color: kLow,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                    barWidth: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem("Injection Attacks", kCritical),
              _buildLegendItem("Cross-Site Scripting", kHigh),
              _buildLegendItem("Authentication Flaws", kPurple),
              _buildLegendItem("Security Misconfiguration", kLow),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: kTextSubtle,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1200;
    final isMedium = size.width >= 900 && size.width < 1200;
    final horizontalPad = isWide ? 56.0 : (isMedium ? 40.0 : 20.0);
    final verticalGap = isWide ? 24.0 : 18.0;
    if (_scanData == null) {
      print('ResultsPage _scanData is null in build method, using fallback data');
      _scanData = {
        'url': 'https://example.com',
        'sqli_vulnerabilities': ['SQLi vuln 1'],
        'xss_vulnerabilities': ['XSS vuln 1'],
        'command_injection_vulnerabilities': [],
        'lfi_vulnerabilities': [],
        'ai_analysis': [
          {'vulnerability_type': 'Weak Password', 'severity': 'High', 'description': 'Weak password', 'recommendation': 'Use strong password'}
        ]
      };
      _summary = buildSummary(_scanData!);
      _url = _scanData!['url']!.toString();
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBg,
      drawer: Drawer(
        backgroundColor: kSurface,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: kSurfaceAlt),
              child: Row(children: const [
                Icon(Icons.security, color: kBlue, size: 28),
                SizedBox(width: 8),
                Text("VulScanner", style: TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
            ListTile(
                leading: const Icon(Icons.home, color: kText),
                title: const Text("Dashboard", style: TextStyle(color: kText)),
                onTap: () => Navigator.pushNamed(context, '/')),
            ListTile(
                leading: const Icon(Icons.history, color: kText),
                title: const Text("Scan History", style: TextStyle(color: kText)),
                onTap: () {}),
            ListTile(
                leading: const Icon(Icons.settings, color: kText),
                title: const Text("Settings", style: TextStyle(color: kText)),
                onTap: () {}),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 14),
            decoration: BoxDecoration(
              color: kSurface,
              border: Border(bottom: BorderSide(color: kBorder)),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: const [
                  Icon(Icons.security, color: kBlue),
                  SizedBox(width: 8),
                  Text("VulScanner", style: TextStyle(color: kText, fontSize: 24, fontWeight: FontWeight.w800)),
                ]),
                Row(children: [
                  _buildTopNavItem("Home", false, _navigateToHome),
                  _buildTopNavItem("Progress", false, _navigateToProgress),
                  _buildTopNavItem("Results", true, _navigateToResults),
                  _buildTopNavItem("Reports", false, _navigateToReports),
                ]),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalGap),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Column(children: [
                    const Text("WebSec Scanner", style: TextStyle(color: kText, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text("Comprehensive Results Overview", style: TextStyle(color: kTextSubtle, fontSize: isWide ? 16 : 15)),
                  ]),
                ),
                SizedBox(height: verticalGap),
                LayoutBuilder(builder: (context, constraints) {
                  final tileHeight = (isWide ? 140.0 : 130.0);
                  final uiTotal = _summary!.combinedTotal;
                  final manualTotal = _summary!.manualTotal;
                  final aiTotal = _summary!.aiTotal;
                  return Column(children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                            child: _statTile(
                                title: "Total Vulnerabilities (All)",
                                value: "$uiTotal",
                                gradient: tileGradBlue,
                                icon: Icons.bug_report,
                                height: tileHeight)),
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                            child: _statTile(
                                title: "Manual Findings",
                                value: "$manualTotal",
                                gradient: tileGradTeal,
                                icon: Icons.handyman,
                                height: tileHeight)),
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
                            child: _statTile(
                                title: "AI Findings (by severity)",
                                value: "$aiTotal",
                                gradient: tileGradPurple,
                                icon: Icons.auto_awesome,
                                height: tileHeight)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 36) / 4 : constraints.maxWidth,
                            child: _statTile(
                                title: "Critical",
                                value: "${_summary!.critical}",
                                gradient: tileGradCritical,
                                icon: Icons.dangerous,
                                height: tileHeight)),
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 36) / 4 : constraints.maxWidth,
                            child: _statTile(
                                title: "High",
                                value: "${_summary!.high}",
                                gradient: tileGradHigh,
                                icon: Icons.warning_amber,
                                height: tileHeight)),
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 36) / 4 : constraints.maxWidth,
                            child: _statTile(
                                title: "Medium",
                                value: "${_summary!.medium}",
                                gradient: tileGradMedium,
                                icon: Icons.report,
                                height: tileHeight)),
                        SizedBox(
                            width: isWide ? (constraints.maxWidth - 36) / 4 : constraints.maxWidth,
                            child: _statTile(
                                title: "Low",
                                value: "${_summary!.low}",
                                gradient: tileGradLow,
                                icon: Icons.info_outline,
                                height: tileHeight)),
                      ],
                    ),
                  ]);
                }),

                SizedBox(height: verticalGap),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                      boxShadow: const [BoxShadow(color: Color(0x66000000))]),
                  child: Row(children: [
                    const Icon(Icons.link, color: kBlue),
                    const SizedBox(width: 10),
                    Expanded(child: Text("Scanned URL: $_url", style: const TextStyle(color: kText, fontSize: 16))),
                  ]),
                ),
                SizedBox(height: verticalGap),
                _findingsPanel(_summary!),
                SizedBox(height: verticalGap),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 220),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                      boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 6))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: const [
                      Icon(Icons.auto_awesome, color: kPurple, size: 22),
                      SizedBox(width: 8),
                      Text("AI Summary", style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _aiFilterPill("Critical", showCritical, kCritical, () => setState(() => showCritical = !showCritical)),
                        const SizedBox(width: 8),
                        _aiFilterPill("High", showHigh, kHigh, () => setState(() => showHigh = !showHigh)),
                        const SizedBox(width: 8),
                        _aiFilterPill("Medium", showMedium, kMedium, () => setState(() => showMedium = !showMedium)),
                        const SizedBox(width: 8),
                        _aiFilterPill("Low", showLow, kLow, () => setState(() => showLow = !showLow)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      int cross = 1;
                      if (maxW > 1400) cross = 3;
                      else if (maxW > 900) cross = 2;

                      final filtered = _summary!.aiItems.where((it) {
                        final sev = (it['severity'] ?? 'Low');
                        if (sev == 'Critical' && !showCritical) return false;
                        if (sev == 'High' && !showHigh) return false;
                        if (sev == 'Medium' && !showMedium) return false;
                        if (sev == 'Low' && !showLow) return false;
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("No AI findings match current filters.", style: TextStyle(color: kTextSubtle)),
                        );
                      }

                      return GridView.builder(
                        itemCount: filtered.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.7,
                        ),
                        itemBuilder: (context, index) => _aiCard(filtered[index]),
                      );
                    }),
                  ]),
                ),

                SizedBox(height: verticalGap),
                LayoutBuilder(builder: (context, constraints) {
                  final isSideBySide = constraints.maxWidth >= 1000;
                  if (isSideBySide) {
                    return Row(
                      children: [
                        Expanded(child: _vulnerabilityDistributionOverTime(_summary!)),
                        const SizedBox(width: 16),
                        Expanded(child: _vulnerabilityPieChart(_summary!)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _vulnerabilityDistributionOverTime(_summary!),
                        const SizedBox(height: 16),
                        _vulnerabilityPieChart(_summary!),
                      ],
                    );
                  }
                }),

                SizedBox(height: verticalGap),
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
                        onTap: _scanData == null ? null : _navigateToReports,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.arrow_forward, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Next",
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
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavItem(String title, bool isActive, VoidCallback onPressed) {
    return Container(
      decoration: isActive
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.blue, width: 2)),
            )
          : null,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.blueAccent : Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}