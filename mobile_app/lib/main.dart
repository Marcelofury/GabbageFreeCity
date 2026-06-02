/// Main Entry Point for GFC Flutter App
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/resident/resident_home_screen.dart';
import 'screens/resident/report_garbage_screen.dart';
import 'screens/resident/my_reports_screen.dart';
import 'screens/resident/payments_screen.dart';
import 'screens/resident/report_details_screen.dart';
import 'screens/resident/subscription_screen.dart';
import 'screens/common/about_screen.dart';
import 'screens/common/notifications_screen.dart';
import 'screens/collector/collector_home_screen.dart';
import 'screens/collector/nearby_reports_screen.dart';
import 'screens/collector/my_assignments_screen.dart';
import 'screens/collector/qr_scanner_screen.dart';
import 'screens/collector/history_screen.dart';
import 'screens/collector/assignment_details_screen.dart';
import 'screens/collector/collector_profile_screen.dart';
import 'screens/collector/collector_directions_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_collectors_screen.dart';
import 'screens/admin/admin_collections_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/collector_provider.dart';
import 'providers/location_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/report_provider.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const GarbageFreeCityApp());
  }, (error, stack) {
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
  });
}

class GarbageFreeCityApp extends StatelessWidget {
  const GarbageFreeCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => CollectorProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
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
          '/set-password': (context) => const SetPasswordScreen(),
          '/resident-home': (context) => const ResidentHomeScreen(),
          '/report-garbage': (context) => const ReportGarbageScreen(),
          '/my-reports': (context) => const MyReportsScreen(),
          '/payments': (context) => const PaymentsScreen(),
          '/report-details': (context) => const ReportDetailsScreen(),
          '/subscriptions': (context) => const SubscriptionScreen(),
          '/about': (context) => const AboutScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/collector-home': (context) => const CollectorHomeScreen(),
          '/nearby-reports': (context) => const NearbyReportsScreen(),
          '/my-assignments': (context) => const MyAssignmentsScreen(),
          '/assignment-details': (context) => const AssignmentDetailsScreen(),
          '/collector-directions': (context) => const CollectorDirectionsScreen(),
          '/qr-scanner': (context) => const QRScannerScreen(),
          '/history': (context) => const HistoryScreen(),
          '/collector-profile': (context) => const CollectorProfileScreen(),
          '/admin-home': (context) => const AdminHomeScreen(),
          '/admin-dashboard': (context) => const AdminDashboardScreen(),
          '/admin-collectors': (context) => const AdminCollectorsScreen(),
          '/admin-collections': (context) => const AdminCollectionsScreen(),
        },
      ),
    );
  }
}
