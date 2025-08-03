import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'dashboard_page.dart'; // giriş sonrası yönlendirdiğin ana sayfa

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage(); // Giriş yapılmamış
    }

    if (!user.emailVerified) {
      // Kullanıcı varsa ama doğrulanmamışsa
      FirebaseAuth.instance.signOut(); // Güvenlik için çıkış yap
      return const LoginPage(); // Giriş sayfasına yönlendir
    }

    return const DashboardPage(); // Giriş yapılmış ve e-posta doğrulanmış
  }
}
