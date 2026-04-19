import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'supabase_service.dart';

class AuthenticationException implements Exception {
  AuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._({
    SupabaseClient? client,
  }) : _client = client;

  static final AuthService instance = AuthService._();

  final SupabaseClient? _client;

  final ValueNotifier<AppUser?> _currentUserNotifier =
      ValueNotifier<AppUser?>(null);

  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient get _supabaseClient =>
      _client ?? SupabaseService.instance.client;

  GoTrueClient get _auth => _supabaseClient.auth;

  ValueListenable<AppUser?> get currentUserListenable => _currentUserNotifier;

  AppUser? get currentUser => _currentUserNotifier.value;

  bool get isAuthenticated => currentUser != null;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // 1. Load current user if there is an active session.
    _currentUserNotifier.value = _mapSupabaseUser(_auth.currentUser);

    // 2. Subscribe to auth state changes and keep _currentUserNotifier in sync.
    _authSubscription = _auth.onAuthStateChange.listen((_) {
    _currentUserNotifier.value = _mapSupabaseUser(_auth.currentUser);
    });

    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    try {
      final AuthResponse response = await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final User? user = response.user;
      if (user == null) {
        throw AuthenticationException('Credenciales inválidas.');
      }

      return _mapSupabaseUser(user)!;
    } on AuthException catch (error) {
      throw AuthenticationException(
        error.message.isNotEmpty
            ? error.message
            : 'Credenciales inválidas.',
      );
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw AuthenticationException(
        'Error inesperado al conectar con el servidor.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

  Future<AppUser> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _ensureInitialized();

    try {
      final AuthResponse response = await _auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: <String, dynamic>{
          if (fullName != null) 'full_name': fullName,
        },
      );

      final User? user = response.user;
      if (user == null) {
        throw AuthenticationException('No se pudo completar el registro.');
      }

      return _mapSupabaseUser(user)!;
    } on AuthException catch (error) {
      if (error.message.contains('already registered') ||
          error.message.contains('already been registered')) {
        throw AuthenticationException(
          'El correo ya se encuentra registrado.',
        );
      }
      throw AuthenticationException(error.message);
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw AuthenticationException(
        'Error inesperado al conectar con el servidor.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    await _ensureInitialized();

    await _auth.signOut();
    // The onAuthStateChange listener will set _currentUserNotifier to null.
  }

  // ---------------------------------------------------------------------------
  // Update profile
  // ---------------------------------------------------------------------------

  Future<AppUser> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword, // kept for API compatibility, ignored internally
    String? newPassword,
  }) async {
    await _ensureInitialized();

    if (currentUser == null) {
      throw AuthenticationException('No hay una sesión activa.');
    }

    final String trimmedNewPassword = newPassword?.trim() ?? '';
    if (trimmedNewPassword.isNotEmpty && trimmedNewPassword.length < 6) {
      throw AuthenticationException(
        'La contraseña debe tener al menos 6 caracteres.',
      );
    }

    try {
      // --- Update user metadata (full_name) ---
      if (fullName != null) {
        final String trimmedFullName = fullName.trim();
        await _auth.updateUser(
          UserAttributes(
            data: <String, dynamic>{
              'full_name': trimmedFullName.isEmpty ? null : trimmedFullName,
            },
          ),
        );
      }

      // --- Update email ---
      if (email != null) {
        final String normalizedEmail = email.trim().toLowerCase();
        if (normalizedEmail.isEmpty) {
          throw AuthenticationException(
            'El correo electrónico no puede estar vacío.',
          );
        }
        await _auth.updateUser(
          UserAttributes(email: normalizedEmail),
        );
      }

      // --- Update password ---
      if (trimmedNewPassword.isNotEmpty) {
        await _auth.updateUser(
          UserAttributes(password: trimmedNewPassword),
        );
      }

      // Return the freshly updated user.
      final User? updatedUser = _auth.currentUser;
      if (updatedUser == null) {
        throw AuthenticationException('No se pudo actualizar el perfil.');
      }

      return _mapSupabaseUser(updatedUser)!;
    } on AuthException catch (error) {
      if (error.message.contains('already registered') ||
          error.message.contains('already been registered')) {
        throw AuthenticationException(
          'El correo ya se encuentra registrado.',
        );
      }
      throw AuthenticationException(
        error.message.isEmpty
            ? 'No se pudo actualizar el perfil.'
            : error.message,
      );
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw AuthenticationException(
        'No se pudo actualizar el perfil.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AppUser? _mapSupabaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email?.toLowerCase() ?? '',
      fullName: user.userMetadata?['full_name'] as String?,
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
