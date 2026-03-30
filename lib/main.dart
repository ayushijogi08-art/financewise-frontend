import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auth_screen.dart'; // We are going to build this next!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. INITIALIZE HIVE (Only for local settings now)
  await Hive.initFlutter();
  
  // We only need the settings box for your Quick Actions and Safety Percent.
  // The rest of the data lives in the cloud now.
  await Hive.openBox('settings_box');

  runApp(const ProviderScope(child: FinanceWiseApp()));
}

class FinanceWiseApp extends ConsumerWidget {
  const FinanceWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // THE BOUNCER: Check if the user has a VIP Pass (JWT Token)
    final authToken = ref.watch(authProvider);

    return MaterialApp(
      title: 'FinanceWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFFD4AF37),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      ),
      // THE GATES: If authToken is null, show Login. Else, show Dashboard.
      home: authToken == null ? const AuthScreen() : const DashboardScreen(),
    );
  }
}