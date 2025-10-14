// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_database_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isProfileLoading = false; // NEW: Track profile loading separately
  String? _error;
  bool _emailConfirmationRequired = false;
  bool _isPasswordRecoveryInProgress = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _isProfileLoading; // NEW
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isEmailVerified => _user?.emailConfirmedAt != null;
  bool get emailConfirmationRequired => _emailConfirmationRequired;
  String? get userType => _userProfile?['user_type'];
  bool get isPasswordRecoveryInProgress => _isPasswordRecoveryInProgress;
  bool get isProfilePrivate => _userProfile?['is_private'] ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  // Helper to translate auth errors into user-friendly messages
  String _handleAuthError(e) {
    if (e is AuthException) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return 'Invalid email or password. Please try again.';
      } else if (e.message.toLowerCase().contains('user already registered')) {
        return 'An account with this email already exists.';
      } else if (e.message.toLowerCase().contains('password should be at least 6 characters')) {
        return 'Password must be at least 6 characters long.';
      }
      return 'An authentication error occurred. Please try again.';
    }
    return 'An unexpected error occurred. Please try again later.';
  }

  Future<void> _initializeAuth() async {
    await SupabaseService.ensureInitialized();
    _authStateSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (data) {
        final AuthChangeEvent event = data.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecoveryInProgress = true;
        } else if (event != AuthChangeEvent.userUpdated) {
          _isPasswordRecoveryInProgress = false;
        }
        _handleSession(data.session);
      },
      onError: (error) {
        _isLoading = false;
        notifyListeners();
      },
    );
    _handleSession(SupabaseService.client.auth.currentSession);
  }

  Future<void> _handleSession(Session? session) async {
    _user = session?.user;
    if (_user != null) {
      await _loadUserProfile();
    } else {
      _userProfile = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    
    _isProfileLoading = true;
    notifyListeners();
    
    // FIX: More descriptive logging
    debugPrint("📥 AuthProvider: Loading user profile for user ID: ${_user!.id}");
    
    _userProfile = await SupabaseDatabaseService.getUserProfile(_user!.id);
    
    if (_userProfile == null) {
      debugPrint("⚠️ AuthProvider: User profile not found, creating new one...");
      _userProfile = await SupabaseDatabaseService.createUserProfile(
        userId: _user!.id,
        email: _user!.email!,
        userType: _user!.userMetadata?['user_type'] ?? 'user',
      );
    }
    
    _isProfileLoading = false;
    debugPrint("✅ AuthProvider: User profile loaded - user_type: ${_userProfile?['user_type']}");
    notifyListeners();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String userType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseAuthService.signUp(
        email: email,
        password: password,
        userType: userType,
      );
      if (response.user != null) {
        _emailConfirmationRequired = response.session == null;
        return true;
      }
      return false;
    } catch (e) {
      _error = _handleAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseAuthService.signIn(email: email, password: password);
      return response.user != null;
    } catch (e) {
      _error = _handleAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;
    try {
      await SupabaseDatabaseService.updateUserProfile(_user!.id, updates);
      await _loadUserProfile(); // Refresh profile data
      return true;
    } catch (e) {
      _error = 'We couldn\'t update your profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> setProfilePrivacy(bool isPrivate) async {
    if (user == null) return;
    try {
      await SupabaseDatabaseService.updateUserProfile(user!.id, {'is_private': isPrivate});
      _userProfile?['is_private'] = isPrivate;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update privacy settings: $e';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await SupabaseAuthService.signOut();
  }
  
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseAuthService.resetPassword(email);
      return true;
    } catch (e) {
      _error = _handleAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> resendConfirmationEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return true;
    } catch (e) {
      _error = 'Failed to resend confirmation email. Please try again shortly.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
