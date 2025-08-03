import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_page.dart';
import 'screens/auth_wrapper.dart';
import 'screens/login_page.dart';
import 'screens/registration_page.dart';
import 'screens/contact_us_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/details_page.dart';
import 'screens/work_page.dart';
import 'screens/profile_page.dart';
import 'screens/market_page.dart';
import 'screens/inventory_page.dart';
import 'screens/goals_page.dart';
import 'screens/leaderboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('tr_TR', null);

  runApp(const VerimalApp());
}

class VerimalApp extends StatelessWidget {
  const VerimalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verimal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7f32a8)),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/auth_wrapper': (context) => const AuthWrapper(),
        '/contact':(context) => const ContactUsPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/profile': (context) => const ProfilePage(),
        '/market': (context) => const MarketPage(),
        '/inventory': (context) => const InventoryPage(),
        '/goals': (context) => const GoalsPage(),
        '/leaderboard': (context) => const LeaderboardPage(),
        '/details': (context) => const DetailsPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/work') {
          final data = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => WorkPage(
              topic: data['topic']!,
              background: data['background']!,
              sound: data['sound']!,
            ),
          );
        }
        return null;
      },
    );
  }
}