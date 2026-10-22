import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:forms_app/firebase_options.dart';
import 'package:forms_app/signinpage.dart';
import 'package:forms_app/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Solo para pruebas locales: flutter build web --dart-define=USE_EMULATOR=true
  // Apunta la app a los emuladores de Firebase en lugar de producción.
  const usarEmulador = bool.fromEnvironment('USE_EMULATOR');
  if (usarEmulador) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate],
      supportedLocales: const [Locale('es'), Locale('en')],
      title: 'CyMA - Encuestas MOP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => SignInPage(),
      },
    );
  }
}
