import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:convert';
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
        if (sev == 'Critical') {
          critical++;
        } else if (sev == 'High') {
          high++;
        } else if (sev == 'Medium') {
          medium++;
        } else {
          low++;
        }
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
const Color kSurface = Color(0xFF161B22);
const Color kBorder = Color(0xFF2E3440);

class ReportExportPage extends StatefulWidget {
  ReportExportPage({Key? key}) : super(key: key);

  @override
  _ReportExportPageState createState() => _ReportExportPageState();
}

class _ReportExportPageState extends State<ReportExportPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _showJson = false;
  String? _jsonOutput;

  void _navigateToHome() => Navigator.pushNamed(context, '/');
  void _navigateToProgress() => Navigator.pushNamed(context, '/progress');

  void _navigateToResults(Map<String, dynamic>? scanData, List<String>? logs) {
    Navigator.pushNamed(context, '/result', arguments: {'scanData': scanData, 'logs': logs});
  }

  void _navigateToReports(Map<String, dynamic>? scanData, List<String>? logs) {
    Navigator.pushNamed(context, '/reports', arguments: {'scanData': scanData, 'logs': logs});
  }

  String _generateJsonData(Map<String, dynamic>? scanData) {
    if (scanData == null) return '{}';

    final summary = buildSummary(scanData);
    final url = scanData['url']?.toString() ?? 'Unknown URL';

    final int sqli = summary.sqli;
    final int xss = summary.xss;
    final int cmdi = summary.cmdi;
    final int rbacIssues = summary.lfi;

    final int csrf = (scanData['csrf_vulnerabilities'] is List)
        ? (scanData['csrf_vulnerabilities'] as List).length
        : 0;

    final int brokenAuth = (scanData['broken_auth_vulnerabilities'] is List)
        ? (scanData['broken_auth_vulnerabilities'] as List).length
        : 0;

    final List<Map<String, dynamic>> vulnItems = [];

    if (sqli > 0) {
      vulnItems.add({
        'type': 'SQL Injection',
        'severity': 'Critical',
        'instances': sqli,
        'components': '/login, /search',
        'recommendation': 'Use parameterized queries and enforce strict input validation.',
      });
    }

    if (xss > 0) {
      vulnItems.add({
        'type': 'Cross-Site Scripting (XSS)',
        'severity': 'High',
        'instances': xss,
        'components': '/comments, /profile',
        'recommendation': 'Apply content security policy and escape user inputs.',
      });
    }

    if (csrf > 0) {
      vulnItems.add({
        'type': 'CSRF',
        'severity': 'High',
        'instances': csrf,
        'components': '/transfer',
        'recommendation': 'Use anti-CSRF tokens and enforce SameSite cookies.',
      });
    }

    if (cmdi > 0) {
      vulnItems.add({
        'type': 'Command Injection',
        'severity': 'Critical',
        'instances': cmdi,
        'components': '/admin/tools',
        'recommendation': 'Avoid shell execution and use safe APIs.',
      });
    }

    if (brokenAuth > 0) {
      vulnItems.add({
        'type': 'Broken Authentication',
        'severity': 'Medium',
        'instances': brokenAuth,
        'components': '/auth',
        'recommendation': 'Enforce multi-factor authentication and secure sessions.',
      });
    }

    if (rbacIssues > 0) {
      vulnItems.add({
        'type': 'RBAC Issues',
        'severity': 'Low',
        'instances': rbacIssues,
        'components': '/admin',
        'recommendation': 'Apply least privilege and validate access controls.',
      });
    }

    for (final it in summary.aiItems) {
      vulnItems.add({
        'type': it['type'] ?? 'AI Finding',
        'severity': it['severity'] ?? 'Low',
        'instances': 1,
        'components': '/unknown',
        'recommendation': (it['recommendation'] ?? '').toString(),
      });
    }

    final List<String> remediationSteps = (scanData['remediation_steps'] is List)
        ? (scanData['remediation_steps'] as List).map((e) => e.toString()).toList()
        : [
            'Fix SQL Injection by using parameterized queries and input validation.',
            'Harden authentication with MFA and secure session handling.',
            'Mitigate XSS by sanitizing inputs and enforcing CSP.',
            'Implement anti-CSRF tokens and SameSite cookie policies.',
            'Restrict OS command execution and switch to safe APIs.',
            'Review RBAC configurations to enforce least privilege.',
          ];

    final List<String> nextSteps = (scanData['next_steps'] is List)
        ? (scanData['next_steps'] as List).map((e) => e.toString()).toList()
        : [
            'Patch critical vulnerabilities immediately and retest.',
            'Apply high-severity fixes and re-run the scanner.',
            'Monitor authentication logs for suspicious activity.',
            'Review role-based access controls and enforce least privilege.',
            'Schedule a follow-up security audit after remediation.',
          ];

    final Map<String, dynamic> jsonData = {
      'scanner': 'Custom Web App Scanner v2.0',
      'scan_summary': {
        'last_scan': '09 Sep 2025 22:15 UTC',
        'total_vulnerabilities': summary.combinedTotal,
        'critical_issues': summary.critical,
      },
      'executive_summary':
          'The assessment revealed ${summary.combinedTotal} vulnerabilities in the application, including ${summary.critical} critical issues. The report provides a detailed breakdown of findings, their severity, and prioritized remediation steps to reduce overall risk exposure.',
      'ai_analysis_summary': {
        'critical': 'SQL injection and command injection vulnerabilities pose immediate risk to core systems.',
        'high': 'Multiple XSS and CSRF vulnerabilities allow attackers to bypass trust boundaries.',
        'medium': 'Broken authentication and DoS concerns affect stability and user security.',
        'low': 'RBAC misconfigurations were noted but do not pose an immediate threat.',
        'recommendation': 'Address critical issues first within 7 days, then resolve high and medium severity vulnerabilities.',
      },
      'vulnerability_distribution': {
        'SQL Injection': sqli,
        'XSS': xss,
        'CSRF': csrf,
        'Command Injection': cmdi,
        'Broken Authentication': brokenAuth,
        'RBAC Issues': rbacIssues,
      },
      'severity_breakdown': {
        'critical': summary.critical,
        'high': summary.high,
        'medium': summary.medium,
        'low': summary.low,
      },
      'vulnerabilities': vulnItems,
      'remediation_steps': remediationSteps,
      'risk_summary':
          'Critical vulnerabilities should be patched within 7 days. High severity issues within 2 weeks. Medium and low issues should be resolved within a month as part of broader application hardening.',
      'next_steps': nextSteps,
    };

    return json.encode(jsonData, toEncodable: (obj) => obj.toString());
  }

  void _generateAndShowJson(Map<String, dynamic>? scanData) {
    if (scanData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No scan data available for JSON export')),
      );
      return;
    }
    final raw = _generateJsonData(scanData);
    final decoded = json.decode(raw);
    const encoder = JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(decoded);
    setState(() {
      _jsonOutput = pretty;
      _showJson = true;
    });
  }

  pw.Widget _sectionTitle(String text, {PdfColor color = PdfColors.blue}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 35),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [
            PdfColor.fromInt((color.toInt() & 0xFFFFFF) | 0x1F000000),
            PdfColors.white,
          ],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromInt((color.toInt() & 0xFFFFFF) | 0x80000000)),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
    );
  }

  pw.Widget _kpiBadge(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt((color.toInt() & 0xFFFFFF) | 0x14000000),
        border: pw.Border.all(color: PdfColor.fromInt((color.toInt() & 0xFFFFFF) | 0x80000000)),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  Future<Uint8List> _generateScanPdf(VulnSummary summary, String url) async {
    final pdf = pw.Document();

    final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7', 'Week 8'];
    final injectionData = [4.0, 3.0, 5.0, 2.0, 1.0, 2.0, 1.0, 2.0];
    final xssData = [7.0, 6.0, 8.0, 5.0, 4.0, 6.0, 3.0, 5.0];
    final authData = [2.0, 3.0, 1.0, 4.0, 2.0, 1.0, 3.0, 2.0];
    final configData = [11.0, 9.0, 13.0, 7.0, 8.0, 10.0, 6.0, 7.0];

    final lineChartData = List<List<String>>.generate(
      weeks.length,
      (i) => [weeks[i], injectionData[i].toString(), xssData[i].toString(), authData[i].toString(), configData[i].toString()],
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blue200, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('VulScanner Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 8),
                pw.Text('Scan Results Overview', style: pw.TextStyle(fontSize: 12, color: PdfColors.blue600)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 5),
                pw.Text('Scanned URL: $url', style: pw.TextStyle(fontSize: 14, color: PdfColors.black)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _kpiBadge('Total Vulnerabilities', '${summary.combinedTotal}', PdfColors.blue),
              _kpiBadge('Manual Findings', '${summary.manualTotal}', PdfColors.green),
              _kpiBadge('AI Findings', '${summary.aiTotal}', PdfColors.orange),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Key Statistics'),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                  pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                ],
              ),
              pw.TableRow(
                decoration: summary.critical > 0 ? pw.BoxDecoration(color: PdfColors.red100) : null,
                children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Critical')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.critical}'))],
              ),
              pw.TableRow(
                decoration: summary.high > 0 ? pw.BoxDecoration(color: PdfColors.orange100) : null,
                children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('High')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.high}'))],
              ),
              pw.TableRow(
                decoration: summary.medium > 0 ? pw.BoxDecoration(color: PdfColors.yellow100) : null,
                children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Medium')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.medium}'))],
              ),
              pw.TableRow(
                decoration: summary.low > 0 ? pw.BoxDecoration(color: PdfColors.green100) : null,
                children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Low')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.low}'))],
              ),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Vulnerabilities')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.combinedTotal}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Manual Findings')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.manualTotal}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('AI Findings')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.aiTotal}'))]),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Findings by Category', color: PdfColors.green),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                  pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Count', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                ],
              ),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('SQL Injection')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.sqli}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('XSS')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.xss}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Command Injection')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.cmdi}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('LFI')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.lfi}'))]),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('AI Findings', color: PdfColors.orange),
          pw.SizedBox(height: 10),
          ...summary.aiItems.map((item) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Type: ${item['type']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                        pw.Text('Severity: ${item['severity']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _getSeverityColor(item['severity']!))),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Paragraph(text: 'Description: ${item['description']}', style: pw.TextStyle(fontSize: 12)),
                    if ((item['recommendation'] ?? '').isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Paragraph(text: 'Recommendation: ${item['recommendation']}', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.green700)),
                    ],
                  ],
                ),
              )),
          pw.SizedBox(height: 20),
          _sectionTitle('Vulnerability Distribution'),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                  pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('Count', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                ],
              ),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('SQLi')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.sqli}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('XSS')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.xss}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('CMDi')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.cmdi}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('LFI')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.lfi}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Critical (AI)')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.critical}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('High (AI)')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.high}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Medium (AI)')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.medium}'))]),
              pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Low (AI)')), pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${summary.low}'))]),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Vulnerability Trends Over Time'),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: const ['Week', 'Injection Attacks', 'XSS', 'Authentication Flaws', 'Misconfiguration'],
            data: lineChartData,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue100),
            cellHeight: 20,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  PdfColor _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return PdfColors.red;
      case 'High':
        return PdfColors.orange;
      case 'Medium':
        return PdfColors.amber;
      case 'Low':
        return PdfColors.green;
      default:
        return PdfColors.grey;
    }
  }

  Widget _buildJsonDisplay(String jsonString) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SelectableText(
                jsonString,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final Map<String, dynamic>? scanData = args?['scanData'] as Map<String, dynamic>?;
    final List<String>? logs = (args?['logs'] is List) ? (args!['logs'] as List).map((e) => e.toString()).toList() : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBg,
      drawer: _buildDrawer(context, scanData, logs),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: kSurface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
                  const Icon(Icons.security, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 5),
                  const Text('VulScanner', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ]),
                Row(children: [
                  _buildTopNavItem('Home', false, () => _navigateToHome()),
                  _buildTopNavItem('Progress', false, () => _navigateToProgress()),
                  _buildTopNavItem('Results', false, () => _navigateToResults(scanData, logs)),
                  _buildTopNavItem('Reports', true, () => _navigateToReports(scanData, logs)),
                ]),
              ],
            ),
          ),
          SizedBox(
            height:40
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: 500,
                    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 35),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Export Reports", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                        const SizedBox(height: 32),
                        _exportCard(
                          context,
                          icon: Icons.code,
                          iconColor: Colors.blueAccent,
                          title: "JSON Export",
                          subtitle: "Developer-friendly format",
                          onTap: () => _generateAndShowJson(scanData),
                        ),
                        const SizedBox(height: 20),
                        _exportCard(
                          context,
                          icon: Icons.bar_chart_rounded,
                          iconColor: Colors.greenAccent,
                          title: "CSV Export",
                          subtitle: "Excel-compatible format",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV export not implemented')));
                          },
                        ),
                        const SizedBox(height: 20),
                        _exportCard(
                          context,
                          icon: Icons.picture_as_pdf,
                          iconColor: Colors.redAccent,
                          title: "PDF Report",
                          subtitle: "Professional presentation format",
                          onTap: () async {
                            if (scanData == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No scan data available for export')));
                              return;
                            }
                            final summary = buildSummary(scanData);
                            final url = scanData['url']?.toString() ?? 'Unknown URL';
                            showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                            try {
                              final bytes = await _generateScanPdf(summary, url);
                              await Printing.sharePdf(bytes: bytes, filename: 'vulscan_results_${DateTime.now().millisecondsSinceEpoch}.pdf');
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
                            } finally {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Start New Scan', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF21262C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: const BorderSide(color: Color(0xFF2E3440)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Advanced Settings', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: _showJson,
                    child: Container(
                      width: 800,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'JSON Output',
                                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _showJson = false),
                                child: const Text(
                                  'Hide JSON',
                                  style: TextStyle(color: Colors.blueAccent, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_jsonOutput != null) _buildJsonDisplay(_jsonOutput!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportCard(BuildContext context, {required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.09), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 36, color: iconColor),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF10161D), borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                child: const Icon(Icons.download_for_offline, color: Colors.white54, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavItem(String title, bool isActive, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: isActive ? const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.blue, width: 2))) : null,
      child: TextButton(
        onPressed: onPressed,
        child: Text(title, style: TextStyle(color: isActive ? Colors.blueAccent : Colors.grey, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Map<String, dynamic>? scanData, List<String>? logs) {
    return Drawer(
      backgroundColor: const Color(0xFF161B22),
      child: ListView(
        padding: EdgeInsets.zero,
        children: const [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF0D1117)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.security, color: Colors.blueAccent, size: 32),
                SizedBox(width: 12),
                Text("VulScanner", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(leading: Icon(Icons.home, color: Colors.white), title: Text("Dashboard", style: TextStyle(color: Colors.white))),
          ListTile(leading: Icon(Icons.history, color: Colors.white), title: Text("Scan History", style: TextStyle(color: Colors.white))),
          ListTile(leading: Icon(Icons.auto_awesome, color: Colors.purpleAccent), title: Text("AI Analysis", style: TextStyle(color: Colors.white))),
          ListTile(leading: Icon(Icons.settings, color: Colors.white), title: Text("Settings", style: TextStyle(color: Colors.white))),
          Divider(color: Color(0xFF2E3440)),
          ListTile(leading: Icon(Icons.help, color: Colors.blueAccent), title: Text("Help & Support", style: TextStyle(color: Colors.white))),
          ListTile(leading: Icon(Icons.info, color: Colors.blueAccent), title: Text("About", style: TextStyle(color: Colors.white))),
          Divider(color: Color(0xFF2E3440)),
          ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}