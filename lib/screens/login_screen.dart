import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/common.dart';
import 'register_screen.dart';

/// Login screen with email + password and a role selector (Patient / Doctor).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  String? _error;
  String _selectedRole = 'patient';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.login(_email.text, _password.text);

      // Verify that the account's stored role matches the selected role.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final storedRole = doc.data()?['role'] ?? 'patient';
          if (storedRole != _selectedRole) {
            await AuthService.logout();
            if (mounted) {
              setState(() {
                _error =
                    'This account is registered as ${_roleName(storedRole)}. '
                    'Please select "${_roleName(storedRole)}" to login.';
                _loading = false;
              });
            }
            return;
          }
        }
      }
      // AuthGate handles routing.
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  String _roleName(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor';
      default:
        return 'Patient';
    }
  }

  Future<void> _forgot() async {
    final ctrl = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Registered email',
            hintText: 'e.g. name@gmail.com',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || !mounted) return;
    final emailError = validateEmail(email);
    if (emailError != null) {
      showMsg(context, emailError, error: true);
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (mounted) {
        showMsg(context,
            'Password reset email sent! Check your inbox and spam folder.');
      }
    } catch (e) {
      if (mounted) showMsg(context, AuthService.message(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      formMaxWidth: 440,
      builder: (context, isWide) => Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo header (brand panel shows it on wide screens)
                    if (!isWide) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_hospital,
                            size: 52, color: kPrimary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('MedBridge',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: kPrimary)),
                    const Text('Bridging Care. Connecting Lives.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),
                    ],
                    Text('Welcome Back!',
                        textAlign: isWide ? TextAlign.left : TextAlign.center,
                        style: TextStyle(
                            fontSize: isWide ? 28 : 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Please login to continue',
                        textAlign: isWide ? TextAlign.left : TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                    SizedBox(height: isWide ? 28 : 20),

                    // Role selector — Patient / Doctor only
                    const Text('Login as',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'patient',
                            label: Text('Patient'),
                            icon: Icon(Icons.person)),
                        ButtonSegment(
                            value: 'doctor',
                            label: Text('Doctor'),
                            icon: Icon(Icons.medical_services)),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (s) =>
                          setState(() => _selectedRole = s.first),
                    ),
                    const SizedBox(height: 20),

                    // Email field — strict @gmail.com validation
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'e.g. name@gmail.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 14),

                    // Password field
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hide ? 'Show password' : 'Hide password',
                          icon: Icon(
                              _hide ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _login(),
                    ),

                    // Error display
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style:
                                      TextStyle(color: Colors.red.shade800)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _forgot,
                          child: const Text('Forgot Password?')),
                    ),

                    // Login button
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('LOGIN'),
                    ),
                    const SizedBox(height: 12),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen())),
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}
