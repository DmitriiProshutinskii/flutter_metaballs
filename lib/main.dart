import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_metaballs/metaballs.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _useLightStatusBar = true;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _useLightStatusBar
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: MetaBallsView(
              onStatusBarStyleChange: (useLightBar) {
                if (mounted) {
                  setState(() => _useLightStatusBar = useLightBar);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
