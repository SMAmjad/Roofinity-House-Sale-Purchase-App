import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/role_router.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => loading = true);
    try {
      final user = email == AuthService.adminEmail
          ? await _authService.signInAdmin(password: password)
          : await _authService.signIn(email: email, password: password);
      if (user == null) throw Exception();

      final home = homeForRole(await _authService.getRole(user.uid));
      if (home == null) {
        await _authService.signOut();
        _showError('Your account profile was not found. Please contact support.');
        return;
      }
      if (!mounted) return;
      goToRoot(context, home);
    } catch (e) {
      _showError(AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Image.asset('assets/images/splash_logo.png', height: 166),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _email,
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: _password, hintText: "Password", isPassword: true),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: loading
                    ? const CircularProgressIndicator()
                    : CustomButton(
                        key: const ValueKey('loginButton'),
                        text: "Login",
                        onPressed: _login,
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text("Create Account", style: TextStyle(color: Color(0xFF005D8C))),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            ],
          ),
        ),
      ),
    );
  }
}
