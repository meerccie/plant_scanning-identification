// Create a new file: pages/deep_link_debug_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class DeepLinkDebugPage extends StatefulWidget {
  const DeepLinkDebugPage({super.key});

  @override
  State<DeepLinkDebugPage> createState() => _DeepLinkDebugPageState();
}

class _DeepLinkDebugPageState extends State<DeepLinkDebugPage> {
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _gatherDebugInfo();
  }

  Future<void> _gatherDebugInfo() async {
    final session = SupabaseService.client.auth.currentSession;
    final user = SupabaseService.client.auth.currentUser;
    
    setState(() {
      _debugInfo = '''
=== AUTH DEBUG INFO ===
Session exists: ${session != null}
User exists: ${user != null}
User email: ${user?.email}
Session expires at: ${session?.expiresAt}
Current timestamp: ${DateTime.now().millisecondsSinceEpoch ~/ 1000}
Session valid: ${session != null && (session.expiresAt ?? 0) > DateTime.now().millisecondsSinceEpoch ~/ 1000}

=== STORAGE INFO ===
// Add storage check if needed

=== END DEBUG INFO ===
''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Link Debug'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _debugInfo,
              style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _gatherDebugInfo,
              child: const Text('Refresh Debug Info'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await SupabaseService.client.auth.signOut();
                _gatherDebugInfo();
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}