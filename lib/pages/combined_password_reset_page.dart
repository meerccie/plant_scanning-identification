// lib/pages/combined_password_reset_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../components/input_field.dart';
import '../components/custom_button.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_auth_service.dart'; // UPDATED

class CombinedPasswordResetPage extends StatefulWidget {
  final String email;
  const CombinedPasswordResetPage({super.key, required this.email});

  @override
  State<CombinedPasswordResetPage> createState() => _CombinedPasswordResetPageState();
}

class _CombinedPasswordResetPageState extends State<CombinedPasswordResetPage> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final success = await SupabaseAuthService.updatePassword(_passwordController.text); // UPDATED
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully! Please log in.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Enter a new password for ${widget.email}'),
              CustomInputField(
                controller: _passwordController,
                label: 'New Password',
                obscure: true,
                validator: (val) => (val?.length ?? 0) < 6 ? 'Password too short' : null,
              ),
              const SizedBox(height: 20),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => CustomButton(
                  onPressed: _handleResetPassword,
                  text: 'Reset Password',
                  isLoading: auth.isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}