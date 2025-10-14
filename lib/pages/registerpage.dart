// lib/pages/registerpage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../components/input_field.dart';
import '../components/custom_button.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _retypePasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedRole = 'User';
  final List<String> _roles = ['User', 'Seller'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userType = _selectedRole.toLowerCase();

    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      userType: userType,
    );

    if (!mounted) return;

    if (success) {
      if (authProvider.emailConfirmationRequired) {
        Navigator.pushReplacementNamed(
          context,
          '/email-confirmation',
          arguments: _emailController.text.trim(),
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _goToLogin() {
    Navigator.pop(context);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
      return 'Please enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 30),
                      Image.asset(
                        'assets/images/plant_img1.png',
                        width: MediaQuery.of(context).size.width * 0.18,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Register',
                        // Uses Pacifico from theme
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontSize: 30,
                              color: AppColors.primaryColor,
                            ),
                      ),
                      const SizedBox(height: 10),
                      CustomInputField(
                        controller: _emailController,
                        label: 'Email',
                        validator: _validateEmail,
                      ),
                      CustomInputField(
                        controller: _passwordController,
                        label: 'Password',
                        obscure: true,
                        validator: _validatePassword,
                      ),
                      CustomInputField(
                        controller: _retypePasswordController,
                        label: 'Confirm password',
                        obscure: true,
                        validator: _validateConfirmPassword,
                      ),
                      _RoleToggle(
                        selectedRole: _selectedRole,
                        roles: _roles,
                        onChanged: (value) => setState(() => _selectedRole = value),
                      ),
                      const SizedBox(height: 10),
                      Consumer<AuthProvider>(
                        builder: (context, auth, child) {
                          return CustomButton(
                            onPressed: _register,
                            text: 'Register',
                            isLoading: auth.isLoading,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: _goToLogin,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final String selectedRole;
  final List<String> roles;
  final ValueChanged<String> onChanged;

  const _RoleToggle({
    required this.selectedRole,
    required this.roles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.65,
      height: 45,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.5)),
      ),
      child: Row(
        children: roles.map((role) {
          final isSelected = role == selectedRole;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.7),
                            blurRadius: 12.0,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [
                          const BoxShadow(
                            color: Colors.transparent,
                            blurRadius: 0.0,
                            offset: Offset(0, 0),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  role,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
