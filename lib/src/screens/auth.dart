// lib/src/screens/auth.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/neon_button.dart';
import '../theme.dart';
import 'dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: AnimatedNeuralBackground(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.neonCyan),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasData) return const DashboardScreen();
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const bool _kLog = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final re = RegExp(r"^[\w.+-]+@[\w-]+\.[\w.-]+$");
    return re.hasMatch(email);
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) {
      if (_kLog) print('[auth] snack-after-dispose: $message');
      return;
    }
    final color = isError ? Colors.red.shade800 : Colors.green.shade700;
    final snack = SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    );
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<bool> _hasNetwork() async {
    try {
      final res =
          await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _friendlyMessageForFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account with that email. Please sign up.';
      case 'wrong-password':
        return 'Incorrect password — try again or reset it.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts — please wait a few minutes.';
      case 'network-request-failed':
        return 'Network error — check your internet connection.';
      case 'internal-error':
        return 'Server error during authentication. Try again later.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled in Firebase console.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  /// Fetch Firestore users/{uid}.name and sync to FirebaseAuth.displayName
  Future<void> _syncDisplayNameFromFirestore(User user) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        final name = (data != null && data['name'] != null) ? data['name'].toString() : null;
        if (name != null &&
            name.isNotEmpty &&
            (user.displayName == null || user.displayName != name)) {
          await user.updateDisplayName(name);
          await user.reload();
        }
      }
    } catch (e) {
      if (_kLog) print('[auth] syncDisplayName error: $e');
    }
  }

  Future<void> _login() async {
    if (_loading) return;

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _showSnack('Please fill both email and password.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    final okNet = await _hasNetwork();
    if (!okNet) {
      _showSnack('No internet — enable Wi-Fi or mobile data and try again.');
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      final user = cred.user;
      if (user != null) {
        await _syncDisplayNameFromFirestore(user);
      }
      _showSnack('Welcome back!', isError: false);
    } on FirebaseAuthException catch (e, st) {
      if (_kLog) print('[auth] FirebaseAuthException: ${e.code} ${e.message}\n$st');
      var friendly = _friendlyMessageForFirebase(e);
      final msgLower = (e.message ?? '').toLowerCase();
      if (msgLower.contains('recaptcha') ||
          e.code == 'web-context-canceled' ||
          e.code == 'unauthorized-domain') {
        friendly += '\nTip: reCAPTCHA / Play Services can fail on emulators — try a real device.';
      }
      _showSnack(friendly);
    } on TypeError catch (t, st) {
      if (_kLog) print('[auth] TypeError: $t\n$st');
      _showSnack('Platform error (plugin mismatch). Try cleaning, upgrading Firebase packages and rebuilding.');
    } catch (e, st) {
      if (_kLog) print('[auth] Unknown login error: $e\n$st');
      _showSnack('Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email to receive a reset link.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    final okNet = await _hasNetwork();
    if (!okNet) {
      _showSnack('No internet — cannot send reset email.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Password reset link sent to your email.', isError: false);
    } on FirebaseAuthException catch (e) {
      if (_kLog) print('[auth] PasswordReset error: ${e.code} ${e.message}');
      _showSnack(_friendlyMessageForFirebase(e));
    } catch (e) {
      if (_kLog) print('[auth] Password reset unknown error: $e');
      _showSnack('Failed to send reset email: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedNeuralBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: AppTheme.neuralGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.neonCyan.withOpacity(0.5),
                                    blurRadius: 40,
                                    spreadRadius: 10)
                              ],
                            ),
                            child: const Icon(Icons.self_improvement,
                                size: 60, color: Colors.white),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.neuralGradient.createShader(bounds),
                        child: const Text('PeacePal',
                            style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    const SizedBox(height: 10),
                    Text('Your AI-Powered Wellness Companion',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16)),
                    const SizedBox(height: 50),
                    GlassCard(
                        child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_loading,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: InputBorder.none),
                    )),
                    const SizedBox(height: 20),
                    GlassCard(
                        child: TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      enabled: !_loading,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: InputBorder.none),
                    )),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _loading ? null : _resetPassword,
                        icon: const Icon(Icons.lock_reset, color: AppTheme.neonCyan),
                        label: const Text('Forgot Password?',
                            style: TextStyle(color: AppTheme.neonCyan)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _loading ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.neonCyan)) : NeonButton(text: 'Login', onPressed: _login),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Don\'t have an account? ', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())), child: const Text('Sign Up', style: TextStyle(color: AppTheme.neonCyan, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 8),
                    if (_kLog) Text('Debug mode: prints enabled', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  static const bool _kLog = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = true}) {
    if (!mounted) return;
    final color = isError ? Colors.red.shade800 : Colors.green.shade700;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
  }

  Future<bool> _hasNetwork() async {
    try {
      final res = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _signUp() async {
    if (_loading) return;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showSnack('Please fill all fields.');
      return;
    }
    if (!RegExp(r"^[\w.+-]+@[\w-]+\.[\w.-]+$").hasMatch(email)) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    final okNet = await _hasNetwork();
    if (!okNet) {
      _showSnack('No internet — cannot create account.');
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);

      // Update FirebaseAuth displayName immediately
      await cred.user?.updateDisplayName(name);
      await cred.user?.reload();

      // Write user document into Firestore (deterministic)
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnack('Account created — welcome!', isError: false);
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (_kLog) print('[auth] SignUp error: ${e.code} ${e.message}');
      String friendly;
      switch (e.code) {
        case 'weak-password':
          friendly = 'Password too weak (min 6 characters).';
          break;
        case 'email-already-in-use':
          friendly = 'Email already in use — try logging in or use a different email.';
          break;
        case 'invalid-email':
          friendly = 'Invalid email address.';
          break;
        case 'network-request-failed':
          friendly = 'Network error — check your connection.';
          break;
        default:
          friendly = e.message ?? 'Sign up failed (${e.code}).';
      }
      _showSnack(friendly);
    } catch (e, st) {
      if (_kLog) print('[auth] SignUp unknown error: $e\n$st');
      _showSnack('Sign up failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.neonCyan), onPressed: () => Navigator.pop(context))),
      body: AnimatedNeuralBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                ShaderMask(shaderCallback: (bounds) => AppTheme.neuralGradient.createShader(bounds), child: const Text('Create Account', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(height: 40),
                GlassCard(child: TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline), border: InputBorder.none))),
                const SizedBox(height: 20),
                GlassCard(child: TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: InputBorder.none))),
                const SizedBox(height: 20),
                GlassCard(child: TextField(controller: _passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), border: InputBorder.none))),
                const SizedBox(height: 40),
                _loading ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.neonCyan)) : NeonButton(text: 'Sign Up', onPressed: _signUp),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
