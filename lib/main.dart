import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fails now, loudly, rather than in front of a user with an empty base URL.
  Env.assertValid();

  // The app is portrait. A dating profile rotated to landscape is a wall of
  // half-height tiles, and none of the layouts were drawn for it.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const ProviderScope(child: EjiojiApp()));
}
