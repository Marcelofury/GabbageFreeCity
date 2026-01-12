/**
 * Main Entry Point for GFC Flutter App
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/resident/resident_home_screen.dart';
import 'screens/resident/report_garbage_screen.dart';
import 'screens/resident/my_reports_screen.dart';
import 'screens/collector/collector_home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/report_provider.dart';

void main() {
  runApp(const GarbageFreeCityApp());
}

class GarbageFreeCityApp extends StatelessWidget {
  const GarbageFreeCityApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: MaterialApp(
        title: 'Garbage Free City',
        debugShowCheckedModeBanner: false,
        
        // Theme
        theme: ThemeData(
          primaryColor: const Color(0xFF2E7D32), // KCCA Green
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            primary: const Color(0xFF2E7D32),
            secondary: const Color(0xFFFF6F00), // Orange accent
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        
        // Routes
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/resident-home': (context) => const ResidentHomeScreen(),
          '/report-garbage': (context) => const ReportGarbageScreen(),
          '/my-reports': (context) => const MyReportsScreen(),
          '/collector-home': (context) => const CollectorHomeScreen(),
        },
      ),
    );
  }
}
