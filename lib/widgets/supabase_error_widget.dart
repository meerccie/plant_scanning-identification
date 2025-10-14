// lib/widgets/supabase_error_widget.dart
import 'package:flutter/material.dart';
import '../pages/firstpage.dart';

class SupabaseErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String errorMessage;

  const SupabaseErrorWidget({
    super.key,
    required this.onRetry,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Connection Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry Connection'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Continue with limited functionality
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const Firstpage()),
                  );
                },
                child: const Text('Continue Offline'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}