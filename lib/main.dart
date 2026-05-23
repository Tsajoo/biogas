import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (make sure your google-services.json / GoogleService-Info.plist are configured)
  await Firebase.initializeApp();
  
  // Enable local persistence so data isn't lost offline
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.ref().keepSynced(true);

  runApp(const BiogasApp());
}

class BiogasApp extends StatelessWidget {
  const BiogasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biogas Monitor',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const MainScreen(),
    );
  }
}

// ==========================================
// MAIN SCREEN (BOTTOM NAVIGATION)
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const RealtimeTab(),
    const HistoryTab(),
    const GraphTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Biogas Sensor Monitor"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.green[700],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: "Realtime",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "History",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: "Graph",
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. REALTIME SENSOR TAB
// ==========================================
class RealtimeTab extends StatelessWidget {
  const RealtimeTab({super.key});

  // Helper to safely parse Firebase numbers
  double _parse(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _editThreshold(BuildContext context, String key, double currentValue) {
    TextEditingController ctrl = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Threshold: $key"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "New Value"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              double? newValue = double.tryParse(ctrl.text);
              if (newValue != null) {
                FirebaseDatabase.instance.ref('config').update({key: newValue});
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(BuildContext context, String title, double value, double threshold, String configKey) {
    bool isBahaya = value > threshold;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
              decoration: BoxDecoration(
                color: isBahaya ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isBahaya ? "BAHAYA" : "AMAN",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Threshold: ${threshold.toStringAsFixed(1)}", style: TextStyle(color: Colors.grey[700])),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editThreshold(context, configKey, threshold),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('config').onValue,
      builder: (context, configSnap) {
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('realtime').onValue,
          builder: (context, realtimeSnap) {
            if (!configSnap.hasData || !realtimeSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Extract Config Data
            final configMap = configSnap.data?.snapshot.value as Map<dynamic, dynamic>? ?? {};
            double suhuThreshold = _parse(configMap['suhuThreshold']);
            double ppmThreshold = _parse(configMap['ppmThreshold']);
            double phThreshold = _parse(configMap['phThreshold']);

            // Extract Realtime Data
            final realtimeMap = realtimeSnap.data?.snapshot.value as Map<dynamic, dynamic>? ?? {};
            double suhu = _parse(realtimeMap['suhu']);
            double ppm = _parse(realtimeMap['ppm']);
            double ph = _parse(realtimeMap['ph']);

            return ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              children: [
                _buildSensorCard(context, "Suhu (°C)", suhu, suhuThreshold, "suhuThreshold"),
                _buildSensorCard(context, "MQ Sensor (PPM)", ppm, ppmThreshold, "ppmThreshold"),
                _buildSensorCard(context, "pH", ph, phThreshold, "phThreshold"),
              ],
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 2. HISTORY TAB
// ==========================================
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      // Listen to history node, limit to avoid massive downloads
      stream: FirebaseDatabase.instance.ref('history').limitToLast(100).onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final map = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
        if (map == null) {
          return const Center(child: Text("No history data available."));
        }

        // Sort keys chronologically (Firebase Push IDs are sorted by time automatically)
        var keys = map.keys.toList()..sort();
        // Reverse so the newest is at the top
        var reversedKeys = keys.reversed.toList();

        return ListView.builder(
          itemCount: reversedKeys.length,
          itemBuilder: (context, index) {
            var key = reversedKeys[index];
            var item = map[key] as Map<dynamic, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.history_edu, color: Colors.white),
                ),
                title: Text("Triggered by: ${item['sensorType'] ?? 'Unknown'}"),
                subtitle: Text(
                  "Suhu: ${item['suhu'] ?? '-'} | PPM: ${item['ppm'] ?? '-'} | pH: ${item['ph'] ?? '-'}",
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 3. GRAPH TAB
// ==========================================
class GraphTab extends StatefulWidget {
  const GraphTab({super.key});

  @override
  State<GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<GraphTab> {
  String selectedMetric = 'suhu'; // Default selected metric

  double _parse(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Selection Buttons
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text("Suhu"),
              selected: selectedMetric == 'suhu',
              onSelected: (val) => setState(() => selectedMetric = 'suhu'),
            ),
            ChoiceChip(
              label: const Text("MQ (PPM)"),
              selected: selectedMetric == 'ppm',
              onSelected: (val) => setState(() => selectedMetric = 'ppm'),
            ),
            ChoiceChip(
              label: const Text("pH"),
              selected: selectedMetric == 'ph',
              onSelected: (val) => setState(() => selectedMetric = 'ph'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Graph
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(right: 20, left: 10, bottom: 20, top: 20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: StreamBuilder<DatabaseEvent>(
              // Get the 20 newest values
              stream: FirebaseDatabase.instance.ref('history').limitToLast(20).onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final map = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                if (map == null || map.isEmpty) {
                  return const Center(child: Text("Not enough data to graph"));
                }

                // Sort keys chronologically
                var sortedKeys = map.keys.toList()..sort();
                
                List<FlSpot> spots = [];
                double xIndex = 0;

                for (var key in sortedKeys) {
                  var item = map[key] as Map<dynamic, dynamic>;
                  double yValue = _parse(item[selectedMetric]);
                  spots.add(FlSpot(xIndex, yValue));
                  xIndex++;
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide index numbers on X axis
                    ),
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.blueAccent,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blueAccent.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}