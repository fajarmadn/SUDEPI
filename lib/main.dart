import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/sudepi_flow_controller.dart';
import 'theme/sudepi_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SudepiApp());
}

class SudepiApp extends StatelessWidget {
  const SudepiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SUDEPI - Suara Deteksi Rupiah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: SudepiTextStyles.fontFamilyName,
        scaffoldBackgroundColor: SudepiColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SudepiColors.primaryBlue,
          primary: SudepiColors.primaryBlue,
          surface: SudepiColors.background,
        ),
      ),
      home: const SudepiFlowController(),
    );
  }
}
