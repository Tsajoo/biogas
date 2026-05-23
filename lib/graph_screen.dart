import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class GraphScreen extends StatefulWidget {
  @override
  _GraphScreenState createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Rolling buffers for each sensor
  List<FlSpot> _suhuSpots = [];
  List<FlSpot> _phSpots = [];
  List<FlSpot> _ppmSpots = [];
  
  int _suhuCount = 0;
  int _phCount = 0;
  int _ppmCount = 0;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen to realtime updates
    _db.child('realtime/suhu').onValue.listen((event) {
      double val = event.snapshot.value as double? ?? 0;
      setState(() {
        _suhuSpots.add(FlSpot(_suhuCount.toDouble(), val));
        _suhuCount++;
        if (_suhuSpots.length > 20) _suhuSpots.removeAt(0);
      });
    });
    
    _db.child('realtime/ph').onValue.listen((event) {
      double val = event.snapshot.value as double? ?? 0;
      setState(() {
        _phSpots.add(FlSpot(_phCount.toDouble(), val));
        _phCount++;
        if (_phSpots.length > 20) _phSpots.removeAt(0);
      });
    });
    
    _db.child('realtime/mq').onValue.listen((event) {
      int val = event.snapshot.value as int? ?? 0;
      setState(() {
        _ppmSpots.add(FlSpot(_ppmCount.toDouble(), val.toDouble()));
        _ppmCount++;
        if (_ppmSpots.length > 20) _ppmSpots.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sensor Graphs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Suhu (°C)'),
            Tab(text: 'pH'),
            Tab(text: 'PPM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLineChart(_suhuSpots, Colors.orange, 'Suhu (°C)'),
          _buildLineChart(_phSpots, Colors.green, 'pH'),
          _buildLineChart(_ppmSpots, Colors.blue, 'PPM'),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> spots, Color color, String title) {
    if (spots.isEmpty) {
      return Center(child: Text('Waiting for sensor data...'));
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}