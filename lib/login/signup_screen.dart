import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../buyer/buyer_dashboard.dart';
import '../seller/seller_dashboard.dart';
import '../utils/role_router.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _akraId = TextEditingController();
  String _role = "Buyer";
  bool loading = false;
  final _auth = AuthService();

  Future<bool> _isAkraIdUnique(String akraId) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('akraId', isEqualTo: akraId)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;
    final akraId = _akraId.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty ||
        (_role == "Seller" && akraId.isEmpty)) {
      _showError("Please fill all required fields.");
      return;
    }
    if (email == AuthService.adminEmail) {
      _showError("This email cannot be used. Please use another email.");
      return;
    }
    if (password.length < 6) {
      _showError("Password must be at least 6 characters.");
      return;
    }
    if (_role == "Seller" && akraId.length != 6) {
      _showError("AKRA ID must be exactly 6 digits.");
      return;
    }

    setState(() => loading = true);

    try {
      if (_role == "Seller" && !await _isAkraIdUnique(akraId)) {
        _showError("This AKRA ID is already in use. Please try another.");
        return;
      }

      final user = await _auth.signUp(
        name: name,
        email: email,
        password: password,
        role: _role,
        akraId: _role == "Seller" ? akraId : null,
      );

      if (user != null && mounted) {
        goToRoot(
          context,
          _role == "Seller" ? const SellerDashboard() : const BuyerDashboard(),
        );
      }
    } catch (e) {
      _showError(AuthService.messageFor(e));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
              Image.asset('assets/images/splash_logo.png', height: 166),
              const SizedBox(height: 10),
              const Text(
                "Create Your Account",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 30),
              CustomTextField(controller: _name, hintText: "Full Name"),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _email,
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _password,
                hintText: "Password",
                isPassword: true,
              ),
              const SizedBox(height: 16),
              if (_role == "Seller")
                CustomTextField(
                  controller: _akraId,
                  hintText: "Enter your 6-digit AKRA ID",
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              if (_role == "Seller") const SizedBox(height: 16),
              DropdownButtonFormField(
                value: _role,
                items: const [
                  DropdownMenuItem(value: "Buyer", child: Text("Buyer")),
                  DropdownMenuItem(value: "Seller", child: Text("Agent")),
                ],
                onChanged: (v) => setState(() => _role = v!),
                decoration: const InputDecoration(labelText: "Role"),
              ),
              const SizedBox(height: 24),
              // ✅ WRAPPED button in an AnimatedSwitcher for a smooth fade
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: loading
                    ? const CircularProgressIndicator()
                    : CustomButton(
                        key: const ValueKey('signupButton'), // Add a key for the switcher to work
                        text: "Sign Up",
                        onPressed: _signup,
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Color(0xFF005D8C)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
