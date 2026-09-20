import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/push/push.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fails now, loudly, rather than in front of a user with an empty base URL.
  Env.assertValid();

  // The app is portrait. A dating profile rotated to landscape is a wall of
  // half-height tiles, and none of the layouts were drawn for it.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Before the first frame, because a notification may be what opened the app
  // and the tap is read back the moment it is on screen. Silent and harmless
  // in a build with no Firebase project.
  await Push.init();

  runApp(const ProviderScope(child: EjiojiApp()));
}
