import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duotask/services/auth_service.dart';

import '../../test_helpers.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late AuthService authService;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.onAuthStateChange).thenAnswer(
      (_) => const Stream.empty(),
    );
    when(mockAuth.currentSession).thenReturn(null);

    authService = AuthService(mockSupabase);
  });

  group('AuthService - Sign In', () {
    test('signInWithEmail fails with invalid credentials', () async {
      // Arrange
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        AuthException('Invalid login credentials', statusCode: '400'),
      );

      // Act
      final result = await authService.signInWithEmail(
        'wrong@example.com',
        'wrongpass',
      );

      // Assert
      expect(result, false);
      expect(authService.errorMessage, isNotNull);
      expect(authService.errorMessage, contains('Invalid'));
      verify(mockAuth.signInWithPassword(
        email: 'wrong@example.com',
        password: 'wrongpass',
      )).called(1);
    });

    test('signInWithEmail handles unexpected errors', () async {
      // Arrange
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        Exception('Unexpected error'),
      );

      // Act
      final result = await authService.signInWithEmail(
        'test@example.com',
        'password123',
      );

      // Assert
      expect(result, false);
      expect(authService.errorMessage, isNotNull);
      expect(authService.errorMessage, contains('unexpected'));
    });

    test('signInWithEmail sets loading state correctly', () async {
      // Arrange
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        AuthException('Invalid credentials'),
      );

      // Act
      expect(authService.isLoading, false);
      final future = authService.signInWithEmail(
        'test@example.com',
        'password123',
      );
      await future;

      // Assert
      expect(authService.isLoading, false);
    });
  });

  group('AuthService - Sign Up', () {
    test('signUpWithEmail fails with existing email', () async {
      // Arrange
      when(mockAuth.signUp(
        email: anyNamed('email'),
        password: anyNamed('password'),
        data: anyNamed('data'),
      )).thenThrow(
        AuthException('User already registered'),
      );

      // Act
      final result = await authService.signUpWithEmail(
        'existing@example.com',
        'password123',
        'Test User',
      );

      // Assert
      expect(result, false);
      expect(authService.errorMessage, contains('already registered'));
      verify(mockAuth.signUp(
        email: 'existing@example.com',
        password: 'password123',
        data: {'display_name': 'Test User'},
      )).called(1);
    });

    test('signUpWithEmail fails with weak password', () async {
      // Arrange
      when(mockAuth.signUp(
        email: anyNamed('email'),
        password: anyNamed('password'),
        data: anyNamed('data'),
      )).thenThrow(
        AuthException('Password should be at least 6 characters'),
      );

      // Act
      final result = await authService.signUpWithEmail(
        'test@example.com',
        '123',
        'Test User',
      );

      // Assert
      expect(result, false);
      expect(authService.errorMessage, contains('at least 6 characters'));
    });
  });

  group('AuthService - Sign Out', () {
    test('signOut succeeds', () async {
      // Arrange
      when(mockAuth.signOut()).thenAnswer((_) async => {});

      // Act
      await authService.signOut();

      // Assert
      expect(authService.currentUser, isNull);
      verify(mockAuth.signOut()).called(1);
    });

    test('signOut handles errors gracefully', () async {
      // Arrange
      when(mockAuth.signOut()).thenThrow(Exception('Sign out failed'));

      // Act
      await authService.signOut();

      // Assert
      expect(authService.errorMessage, isNotNull);
      expect(authService.errorMessage, contains('Sign out failed'));
    });
  });

  group('AuthService - Password Management', () {
    test('resetPassword sends email successfully', () async {
      // Arrange
      when(mockAuth.resetPasswordForEmail(
        any,
        redirectTo: anyNamed('redirectTo'),
      )).thenAnswer((_) async => {});

      // Act
      final result = await authService.resetPassword('test@example.com');

      // Assert
      expect(result, true);
      expect(authService.errorMessage, isNull);
      verify(mockAuth.resetPasswordForEmail(
        'test@example.com',
        redirectTo: anyNamed('redirectTo'),
      )).called(1);
    });

    test('resetPassword handles errors', () async {
      // Arrange
      when(mockAuth.resetPasswordForEmail(
        any,
        redirectTo: anyNamed('redirectTo'),
      )).thenThrow(AuthException('Email not found'));

      // Act
      final result = await authService.resetPassword('invalid@example.com');

      // Assert
      expect(result, false);
      expect(authService.errorMessage, isNotNull);
    });
  });

  group('AuthService - State Management', () {
    test('isAuthenticated returns false initially', () {
      expect(authService.isAuthenticated, false);
    });

    test('isLoading returns false initially', () {
      expect(authService.isLoading, false);
    });

    test('errorMessage is null initially', () {
      expect(authService.errorMessage, isNull);
    });

    test('clearError clears error message', () async {
      // Set an error first
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(AuthException('Test error'));

      await authService.signInWithEmail('test@example.com', 'wrong');
      expect(authService.errorMessage, isNotNull);

      // Clear it
      authService.clearError();
      expect(authService.errorMessage, isNull);
    });
  });

  group('AuthService - Error Messages', () {
    test('provides user-friendly error for invalid credentials', () async {
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        AuthException('Invalid login credentials', statusCode: '400'),
      );

      await authService.signInWithEmail('test@example.com', 'wrong');

      expect(authService.errorMessage, contains('Invalid'));
      expect(authService.errorMessage, isNot(contains('400')));
    });

    test('provides user-friendly error for rate limiting', () async {
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        AuthException('Too many requests', statusCode: '429'),
      );

      await authService.signInWithEmail('test@example.com', 'pass');

      expect(authService.errorMessage, contains('Too many'));
      expect(authService.errorMessage, contains('wait'));
    });
  });
}
