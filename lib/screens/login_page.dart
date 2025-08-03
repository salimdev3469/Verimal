import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _signInWithEmailPassword() async {
    setState(() {
      _error = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = "Lütfen e-posta ve şifre alanlarını doldurun.";
      });
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user != null) {
        await user.reload(); // 🔄 Kullanıcı bilgilerini güncelle
        if (!user.emailVerified) {
          await user.sendEmailVerification(); // 🔔 Doğrulama e-postası gönder
          await FirebaseAuth.instance.signOut(); // 🚪 Oturumu kapat
          setState(() {
            _error =
            "E-posta adresiniz henüz doğrulanmamış. Size bir doğrulama e-postası gönderildi. Lütfen e-postanızı kontrol edin.";
          });
          return;
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard'); // ✅ Giriş başarılı
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _error = "Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.";
            break;
          case 'wrong-password':
            _error = "Hatalı şifre girdiniz.";
            break;
          case 'invalid-email':
            _error = "Geçersiz e-posta adresi.";
            break;
          case 'user-disabled':
            _error = "Bu hesap devre dışı bırakılmış.";
            break;
          default:
            _error = "Giriş yapılırken bir hata oluştu: ${e.message}";
        }
      });
    } catch (e) {
      setState(() {
        _error = "Beklenmeyen bir hata oluştu: $e";
      });
    }
  }

  String _firebaseErrorToTurkish(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Böyle bir kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre yanlış.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf.';
      case 'missing-email':
        return 'E-posta adresi girilmedi.';
      case 'missing-password':
        return 'Şifre girilmedi.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      case 'user-mismatch':
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
      case 'credential-already-in-use':
        return 'Kimlik doğrulama hatası. Lütfen tekrar deneyin.';
      default:
        return e.message ?? 'Bilinmeyen bir hata oluştu.';
    }
  }

  Future<void> _createUserInFirestoreIfNotExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'name': user.displayName ?? '',
        'email': user.email,
        'phone': '',
        'totalWorkSeconds': 0,
        'ownedItems': [],
        'customBackgrounds': [],
        'customSounds': [],
        'coins':10
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _createUserInFirestoreIfNotExists();
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      setState(() => _error = "Google ile giriş yapılamadı: $e");
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Lütfen önce e-posta adresinizi girin.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifre sıfırlama e-postası gönderildi. Spam klasörünü kontrol edin."),duration:Duration(seconds: 3)),
      );
    } catch (e) {
      setState(() => _error = "Şifre sıfırlama başarısız: $e");
    }
  }

  Route _createTransitionRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const RegistrationPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7f32a8),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/verimalWhite.png', width: 280, height: 120),
                const SizedBox(height: 32),
                _buildTextField(_emailController, "E-posta", Icons.email),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, "Şifre", Icons.lock, isPassword: true),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text("Şifremi Unuttum?", style: TextStyle(color: Colors.white70)),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmailPassword,
                  style: _buttonStyle(),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF7f32a8))
                      : const Text("Giriş Yap"),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  style: _buttonStyle(background: Colors.white),
                  icon: Image.asset('assets/images/googleicon.png', width: 24, height: 24),
                  label: const Text("Google ile Giriş Yap", style: TextStyle(color: Color(0xFF7f32a8))),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).push(_createTransitionRoute()),
                  child: const Text("Hesabınız yok mu? Kayıt Ol", style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle({Color background = Colors.white}) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: const Color(0xFF7f32a8),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}