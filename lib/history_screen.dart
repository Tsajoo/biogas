import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref().child('history');
  List<Map<dynamic, dynamic>> _events = [];
  
  @override
  void initState() {
    super.initState();
    _historyRef.onValue.listen((event) {
      Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
      if (data != null) {
        List<Map<dynamic, dynamic>> list = [];
        data.forEach((key, value) {
          value['key'] = key;
          list.add(value);
        });
        list.sort((a,b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        setState(() => _events = list);
      } else {
        setState(() => _events = []);
      }
    });
  }
  
  void _deleteEvent(String key) {
    _historyRef.child(key).remove();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('History')),
      body: _events.isEmpty
          ? Center(child: Text('No threshold events'))
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (ctx, i) {
                var ev = _events[i];
                String time = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(ev['timestamp']));
                return Dismissible(
                  key: Key(ev['key']),
                  background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (_) => _deleteEvent(ev['key']),
                  child: Card(
                    child: ListTile(
                      title: Text(time),
                      subtitle: Text('Suhu: ${ev['suhu']}°C | pH: ${ev['ph']} | PPM: ${ev['ppm']} (Limit ${ev['thresholdLimit']})'),
                    ),
                  ),
                );
              }),
    );
  }
}