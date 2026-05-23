import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'history_screen.dart';
import 'graph_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(BiogasApp());
}

class BiogasApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biogas Monitor',
      theme: ThemeData(primarySwatch: Colors.green),
      home: MainScreen(),
      routes: {
        '/history': (ctx) => HistoryScreen(),
        '/graph': (ctx) => GraphScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final DatabaseReference db = FirebaseDatabase.instance.ref();
  
  double suhu = 0;
  double ph = 0;
  int ppm = 0;
  String status = "✅ AMAN";
  Color statusColor = Colors.green;
  
  // Threshold controllers
  final TextEditingController _suhuThresholdCtrl = TextEditingController();
  final TextEditingController _phThresholdCtrl = TextEditingController();
  final TextEditingController _ppmThresholdCtrl = TextEditingController();
  
  double _suhuLimit = 40;
  double _phLimit = 8.5;
  int _ppmLimit = 1000;
  
  bool _wasExceeded = false;

  @override
  void initState() {
    super.initState();
    _loadThresholds();
    _listenToSensors();
  }

  void _loadThresholds() {
    db.child('config').child('suhuThreshold').onValue.listen((event) {
      setState(() => _suhuLimit = event.snapshot.value as double? ?? 40);
      _suhuThresholdCtrl.text = _suhuLimit.toInt().toString();
    });
    db.child('config').child('phThreshold').onValue.listen((event) {
      setState(() => _phLimit = event.snapshot.value as double? ?? 8.5);
      _phThresholdCtrl.text = _phLimit.toString();
    });
    db.child('config').child('ppmThreshold').onValue.listen((event) {
      setState(() => _ppmLimit = event.snapshot.value as int? ?? 1000);
      _ppmThresholdCtrl.text = _ppmLimit.toString();
    });
  }

  void _listenToSensors() {
    db.child('realtime').child('suhu').onValue.listen((event) {
      setState(() => suhu = event.snapshot.value as double? ?? 0);
      _checkThresholds();
    });
    db.child('realtime').child('ph').onValue.listen((event) {
      setState(() => ph = event.snapshot.value as double? ?? 0);
      _checkThresholds();
    });
    db.child('realtime').child('mq').onValue.listen((event) {
      setState(() => ppm = event.snapshot.value as int? ?? 0);
      _checkThresholds();
    });
  }

  void _checkThresholds() {
    bool suhuExceed = suhu > _suhuLimit;
    bool phExceed = ph > _phLimit;
    bool ppmExceed = ppm > _ppmLimit;
    bool anyExceed = suhuExceed || phExceed || ppmExceed;
    
    if (anyExceed) {
      List<String> warns = [];
      if (suhuExceed) warns.add("Suhu ${suhu}°C > ${_suhuLimit}°C");
      if (phExceed) warns.add("pH ${ph} > ${_phLimit}");
      if (ppmExceed) warns.add("PPM ${ppm} > ${_ppmLimit}");
      setState(() {
        status = "⚠️ BAHAYA! " + warns.join(", ");
        statusColor = Colors.red;
      });
      
      if (!_wasExceeded) {
        // Save to history
        db.child('history').push().set({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'suhu': suhu,
          'ph': ph,
          'ppm': ppm,
          'thresholdLimit': suhuExceed ? _suhuLimit.toInt() : (phExceed ? (_phLimit*10).toInt() : _ppmLimit)
        });
        _wasExceeded = true;
      }
    } else {
      setState(() {
        status = "✅ AMAN";
        statusColor = Colors.green;
      });
      _wasExceeded = false;
    }
  }

  void _saveThresholds() {
    double newSuhu = double.tryParse(_suhuThresholdCtrl.text) ?? 40;
    double newPh = double.tryParse(_phThresholdCtrl.text) ?? 8.5;
    int newPpm = int.tryParse(_ppmThresholdCtrl.text) ?? 1000;
    db.child('config').update({
      'suhuThreshold': newSuhu,
      'phThreshold': newPh,
      'ppmThreshold': newPpm
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thresholds saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Biogas Monitor'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Sensor cards
            Card(child: ListTile(title: Text('🌡️ SUHU'), trailing: Text('${suhu.toStringAsFixed(1)} °C', style: TextStyle(fontSize: 20)))),
            Card(child: ListTile(title: Text('💧 pH'), trailing: Text(ph.toStringAsFixed(1), style: TextStyle(fontSize: 20)))),
            Card(child: ListTile(title: Text('⛽ METANA'), trailing: Text('$ppm ppm', style: TextStyle(fontSize: 20)))),
            SizedBox(height: 8),
            Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            Divider(),
            // Threshold inputs
            Text('⚙️ AMBANG BATAS', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(child: TextField(controller: _suhuThresholdCtrl, decoration: InputDecoration(labelText: 'Suhu max (°C)'), keyboardType: TextInputType.number)),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: _phThresholdCtrl, decoration: InputDecoration(labelText: 'pH max'), keyboardType: TextInputType.number)),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: _ppmThresholdCtrl, decoration: InputDecoration(labelText: 'PPM max'), keyboardType: TextInputType.number)),
            ]),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _saveThresholds, child: Text('Simpan Semua')),
            Spacer(),
            // Bottom navigation (custom)
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton.icon(onPressed: () => Navigator.pushNamed(context, '/history'), icon: Icon(Icons.history), label: Text('History')),
              TextButton.icon(onPressed: () => Navigator.pushNamed(context, '/graph'), icon: Icon(Icons.show_chart), label: Text('Graphs')),
            ]),
          ],
        ),
      ),
    );
  }
}