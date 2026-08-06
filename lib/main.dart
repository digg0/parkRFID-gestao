import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/sessions/presentation/screens/tela_checkin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();


  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('ERRO DO FLUTTER: ${details.exception}');
  };


  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('ERRO ASSÍNCRONO: $error');
    return true;
  };

  runApp(const ParqueApp());
}

class ParqueApp extends StatelessWidget {
  const ParqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parque RFID',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const TelaCheckinMobile(),
    );
  }
}