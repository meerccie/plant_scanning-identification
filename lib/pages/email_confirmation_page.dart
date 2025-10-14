// lib/pages/email_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../components/custom_button.dart';
import '../providers/auth_provider.dart';

class EmailConfirmationPage extends StatelessWidget {
  final String email;

  const EmailConfirmationPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 80, color: AppColors.primaryColor),
              const SizedBox(height: 24),
              const Text('Confirm Your Email', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
              const SizedBox(height: 16),
              Text('We sent a confirmation email to:', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text('Please check your inbox and click the confirmation link to activate your account.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              CustomButton(
                onPressed: () async {
                  final success = await authProvider.resendConfirmationEmail(email);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Confirmation email sent to $email'), backgroundColor: AppColors.success),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(authProvider.error ?? 'Failed to send email'), backgroundColor: AppColors.error),
                    );
                  }
                },
                text: 'Resend Confirmation Email',
                isLoading: authProvider.isLoading,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                child: const Text('Return to Login', style: TextStyle(color: AppColors.primaryColor, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}