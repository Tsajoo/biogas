import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'main_screen.dart';
import 'history_screen.dart';
import 'graph_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ErrorCatcher());
}

class ErrorCatcher extends StatefulWidget {
  const ErrorCatcher({super.key});

  @override
  State<ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<ErrorCatcher> {
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _initialized = true;
      });
    } catch (e, stack) {
      setState(() {
        _error = 'Firebase init failed:\n$e\n\n$stack';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      );
    }
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return const BiogasApp();
  }
}

class BiogasApp extends StatelessWidget {
  const BiogasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biogas Monitor',
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/history': (context) => const HistoryScreen(),
        '/graph': (context) => const GraphScreen(),
      },
    );
  }
}
