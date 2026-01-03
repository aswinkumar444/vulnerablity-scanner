import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
class DoSUtils {
  static final TextEditingController urlController = TextEditingController();
  static bool loading = false;
  static String status = "";
  static Map<String, dynamic> stats = {};
  static Future<void> checkDoS(Function setState) async {
    final url = urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      loading = true;
      status = "";
      stats = {};
    });

    try {
      final response = await http.post(
        Uri.parse("http://localhost:5002/check_dos"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"url": url}),
      );

      final data = jsonDecode(response.body);
      setState(() {
        status = data["status"] ?? "";
        stats = data["stats"] ?? {};
      });
    } catch (e) {
      setState(() {
        status = "Error: $e";
      });
    }

    setState(() {
      loading = false;
    });
  }

  static Widget buildStatusBanner() {
    if (status.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.startsWith("Error") ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status.startsWith("Error") ? Icons.error : Icons.check_circle,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildUrlInput(VoidCallback onScan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 400,
              child: TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: "Target URL",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 0, 0, 0),
                  hintStyle: TextStyle(color: const Color.fromARGB(253, 255, 255, 255)),
                ),
              ),
            ),
            const SizedBox(height: 90),
            Container(
              width: 200,
              child: ElevatedButton(
                onPressed: onScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2), // Blue color from the palette
                  foregroundColor: const Color.fromARGB(255, 250, 0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25), // More rounded like in the image
                  ),
                  elevation: 6,
                  shadowColor: Colors.black26,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 35,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      "Start Scan",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildStatCard(String title, String value, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 150,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  static Widget buildRequestsFailuresChart() {
    if (stats.isEmpty) return const SizedBox();

    final totalRequests = (stats["total_requests"] ?? 0).toDouble();
    final failures = (stats["failures"] ?? 0).toDouble();
    final maxY = (totalRequests > failures ? totalRequests : failures) * 1.1;

    return _chartCard(
      "Requests vs Failures",
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 50)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text("Requests");
                    case 1:
                      return const Text("Failures");
                    default:
                      return const Text("");
                  }
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(
                toY: totalRequests,
                color: Colors.blue,
                width: 40,
                borderRadius: BorderRadius.circular(8),
              )
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(
                toY: failures,
                color: Colors.red,
                width: 40,
                borderRadius: BorderRadius.circular(8),
              )
            ]),
          ],
        ),
      ),
    );
  }

  static Widget buildResponseTimeChart() {
    if (stats.isEmpty) return const SizedBox();

    final avgTime = (stats["avg_response_time"] ?? 0).toDouble();

    return _chartCard(
      "Average Response Time",
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          maxY: avgTime * 1.2,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, _) => Text('${value.toInt()} ms')),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) => const Text("Response Time"),
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(
                toY: avgTime,
                color: Colors.green,
                width: 60,
                borderRadius: BorderRadius.circular(8),
              )
            ]),
          ],
        ),
      ),
    );
  }
  static Widget buildSuccessRateChart() {
    if (stats.isEmpty) return const SizedBox();
    final totalRequests = (stats["total_requests"] ?? 0).toDouble();
    final failures = (stats["failures"] ?? 0).toDouble();
    final successes = totalRequests - failures;
    if (totalRequests == 0) return const SizedBox();

    return _chartCard(
      "Success Rate",
      PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          sections: [
            PieChartSectionData(
              color: Colors.green,
              value: successes,
              title:
                  'Success\n${((successes / totalRequests) * 100).toStringAsFixed(1)}%',
              radius: 80,
              titleStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            PieChartSectionData(
              color: Colors.red,
              value: failures,
              title:
                  'Failures\n${((failures / totalRequests) * 100).toStringAsFixed(1)}%',
              radius: 80,
              titleStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chartCard(String title, Widget chart) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }
}
class DoSHomePage extends StatefulWidget {
  const DoSHomePage({super.key});

  @override
  State<DoSHomePage> createState() => _DoSHomePageState();
}

class _DoSHomePageState extends State<DoSHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.security, size: 28),
            const SizedBox(width: 8),
            const Text("Vul Scanner DOS Attack"),
          ],
        ),
        toolbarHeight: 70,
      ),
      backgroundColor: const Color(0xFF0D1117), // Background color
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DoSUtils.buildStatusBanner(),
              const SizedBox(height: 20),
              DoSUtils.buildUrlInput(() {
                DoSUtils.checkDoS(setState);
              }),
              const SizedBox(height: 30),
              if (DoSUtils.stats.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DoSUtils.buildStatCard(
                        "Total Requests",
                        "${DoSUtils.stats["total_requests"] ?? 0}",
                        Colors.blue),
                    DoSUtils.buildStatCard(
                        "Failures",
                        "${DoSUtils.stats["failures"] ?? 0}",
                        Colors.red),
                  ],
                ),
              const SizedBox(height: 20),
              DoSUtils.buildRequestsFailuresChart(),
              DoSUtils.buildResponseTimeChart(),
              DoSUtils.buildSuccessRateChart(),
            ],
          ),
        ),
      ),
    );
  }
}