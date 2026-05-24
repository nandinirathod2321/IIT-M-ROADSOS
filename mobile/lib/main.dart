import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/database/database_helper.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().initialize();
  runApp(const RoadSOSApp());
}

class RoadSOSApp extends StatelessWidget {
  const RoadSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RoadSOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
