import 'package:flutter/material.dart';
import 'package:newton_particles/newton_particles.dart';

import 'app/app.dart';
import 'core/services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Newton physics engine: required on web (Chipmunk2D FFI), no-op on mobile.
  try {
    await initializeNewton();
  } catch (_) {
    // Never let particle init failure crash the app.
  }
  final services = await AppServices.bootstrap();
  runApp(GridSparkApp(services: services));
}
