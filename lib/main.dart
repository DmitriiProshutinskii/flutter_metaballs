// Entry point for the metaballs demo app. Wires MetaBallsView and status bar style.
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
    // AnnotatedRegion is what actually applies status bar style on the platform. Without it, SystemChrome would need to be used and timing is trickier. MetaBallsView reports whether the content under the status bar is light or dark so we can keep icons readable.
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
