import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/map_screen.dart';
import 'state/alert_controller.dart';
import 'state/permission_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NavSpeedAlertExampleApp());
}

/// App root. Two focused [ChangeNotifier]s at the top of the tree:
///   - [AlertController]      → the alert engine, its streams and voice.
///   - [PermissionController] → runtime location permission.
class NavSpeedAlertExampleApp extends StatelessWidget {
  const NavSpeedAlertExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlertController()..init()),
        ChangeNotifierProvider(
          create: (_) => PermissionController()..refresh(),
        ),
      ],
      child: MaterialApp(
        title: 'Nav Speed Alert',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MapScreen(),
      ),
    );
  }
}
