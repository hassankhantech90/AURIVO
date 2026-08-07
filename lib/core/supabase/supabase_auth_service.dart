import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'supabase_exceptions.dart';
import 'supabase_service.dart';

/// Supabase Auth service exposing reusable authentication primitives.
class SupabaseAuthService {
  const SupabaseAuthService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  supabase.User? get currentUser => _supabaseService.client.auth.currentUser;

  Stream<supabase.AuthState> get authStateChanges =>
      _supabaseService.client.auth.onAuthStateChange;

  Future<supabase.AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      throw SupabaseExceptionMapper.auth(error);
    }
  }

  Future<supabase.AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _supabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
    } catch (error) {
      throw SupabaseExceptionMapper.auth(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _supabaseService.client.auth.signOut();
    } catch (error) {
      throw SupabaseExceptionMapper.auth(error);
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _supabaseService.client.auth.resetPasswordForEmail(email);
    } catch (error) {
      throw SupabaseExceptionMapper.auth(error);
    }
  }
}
