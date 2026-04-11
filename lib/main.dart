import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:planetshield360/screens/intro_screen.dart';

import 'firebase_options.dart';
import 'services/background_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the SENTINEL Continuous Sync Engine
  BackgroundSyncService().startSync();

  runApp(const PlanetShieldApp());
}