import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// User role enum for municipality admin access
enum UserRole {
  superAdmin,
  municipalAdmin,
  fieldEngineer,
}

extension UserRoleExtension on UserRole {
  String get stringValue {
    switch (this) {
      case UserRole.superAdmin:
        return 'SUPER_ADMIN';
      case UserRole.municipalAdmin:
        return 'MUNICIPAL_ADMIN';
      case UserRole.fieldEngineer:
        return 'FIELD_ENGINEER';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      case 'MUNICIPAL_ADMIN':
        return UserRole.municipalAdmin;
      case 'FIELD_ENGINEER':
        return UserRole.fieldEngineer;
      default:
        throw ArgumentError('Unknown role: $value');
    }
  }
}

/// Municipality user model
class MunicipalityUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String municipalityId;

  MunicipalityUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.municipalityId,
  });

  factory MunicipalityUser.fromMap(Map<String, dynamic> map, String id) {
    return MunicipalityUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: UserRoleExtension.fromString(map['role'] ?? 'FIELD_ENGINEER'),
      municipalityId: map['municipality_id'] ?? '',
    );
  }
}

/// Authentication state
class AuthState {
  final bool isAuthenticated;
  final MunicipalityUser? user;
  final String? token;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    MunicipalityUser? user,
    String? token,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      token: token ?? this.token,
      error: error ?? this.error,
    );
  }
}

/// Municipality authentication service
/// Handles login, token management, and session restoration
class MunicipalityAuthService {
  static const String _tokenKey = 'municipality_auth_token';

  final FlutterSecureStorage _secureStorage;

  late final ValueNotifier<AuthState> _authState;

  MunicipalityAuthService({
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _authState = ValueNotifier<AuthState>(const AuthState());
  }

  /// Observable auth state stream
  ValueNotifier<AuthState> get authState => _authState;

  /// Current authentication state
  AuthState get currentState => _authState.value;

  /// Check if user is authenticated
  bool get isAuthenticated => currentState.isAuthenticated;

  /// Get current user
  MunicipalityUser? get currentUser => currentState.user;

  /// Get current token
  String? get token => currentState.token;

  /// Login with email and password
  /// Calls backend Cloud Function via HTTP to authenticate
  Future<bool> login(String email, String password) async {
    try {
      _authState.value = currentState.copyWith(error: null);

      // TODO: Replace with your actual Firebase project ID and region
      const projectId = 'roadsense-3e4b2'; // e.g., 'roadsense-3e4b2'
      const region = 'asia-south1';
      const functionName = 'municipalityLogin';
      
      final url = Uri.parse(
        'https://$region-$projectId.cloudfunctions.net/$functionName',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email.toLowerCase(),
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Login request timed out'),
      );

      // Handle response
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        if (responseData['success'] != true) {
          throw Exception(
            responseData['message'] ?? 'Login failed',
          );
        }

        final token = responseData['token'] as String;
        final userData = responseData['user'] as Map<String, dynamic>;

        // Create user object
        final user = MunicipalityUser(
          id: userData['id'] as String,
          email: userData['email'] as String,
          name: userData['name'] as String,
          role: UserRoleExtension.fromString(userData['role'] as String),
          municipalityId: userData['municipality_id'] as String,
        );

        // Store token securely
        await _secureStorage.write(key: _tokenKey, value: token);

        // Update state
        _authState.value = AuthState(
          isAuthenticated: true,
          user: user,
          token: token,
        );

        return true;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Invalid request');
      } else if (response.statusCode == 401) {
        throw Exception('Invalid email or password');
      } else if (response.statusCode == 403) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorData['message'] ?? 'Access denied',
        );
      } else {
        throw Exception('Login failed with status ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      final errorMsg = 'Network error: ${e.message}';
      _authState.value = currentState.copyWith(
        isAuthenticated: false,
        error: errorMsg,
      );
      return false;
    } on TimeoutException {
      const errorMsg = 'Request timed out. Please try again.';
      _authState.value = currentState.copyWith(
        isAuthenticated: false,
        error: errorMsg,
      );
      return false;
    } catch (e) {
      final errorMsg = e.toString();
      _authState.value = currentState.copyWith(
        isAuthenticated: false,
        error: errorMsg,
      );
      return false;
    }
  }

  /// Restore session from stored token
  /// Called on app startup to maintain session
  Future<bool> restoreSession() async {
    try {
      final storedToken = await _secureStorage.read(key: _tokenKey);

      if (storedToken == null) {
        _authState.value = const AuthState();
        return false;
      }

      // Verify token is still valid via backend
      const projectId = 'roadsense-3e4b2';
      const region = 'asia-south1';
      const functionName = 'verifyToken';

      final response = await http.post(
        Uri.parse(
          'https://$region-$projectId.cloudfunctions.net/$functionName',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $storedToken',
        },
        body: jsonEncode({'token': storedToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        await logout();
        return false;
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (responseData['valid'] != true) {
        // Token expired or invalid
        await logout();
        return false;
      }

      // Token is valid, restore session
      _authState.value = AuthState(
        isAuthenticated: true,
        token: storedToken,
      );

      return true;
    } catch (e) {
      print('Error restoring session: $e');
      await logout();
      return false;
    }
  }

  /// Logout and clear session
  Future<void> logout() async {
    try {
      final token = currentState.token;

      // Log logout on backend if token exists
      if (token != null) {
        try {
          const projectId = 'roadsense-3e4b2';
          const region = 'asia-south1';
          const functionName = 'municipalityLogout';

          await http.post(
            Uri.parse(
              'https://$region-$projectId.cloudfunctions.net/$functionName',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'token': token}),
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          // Continue with logout even if backend logging fails
          print('Error logging logout: $e');
        }
      }

      // Clear stored token
      await _secureStorage.delete(key: _tokenKey);

      // Reset auth state
      _authState.value = const AuthState();
    } catch (e) {
      print('Error during logout: $e');
      _authState.value = const AuthState();
    }
  }

  /// Check if current user has a specific role
  bool hasRole(UserRole role) {
    return isAuthenticated && currentUser?.role == role;
  }

  /// Check if current user can access a municipality
  bool canAccessMunicipality(String municipalityId) {
    if (!isAuthenticated) return false;
    final user = currentUser;
    if (user == null) return false;

    // SUPER_ADMIN can access all municipalities
    if (user.role == UserRole.superAdmin) return true;

    // Others can only access their own municipality
    return user.municipalityId == municipalityId;
  }

  /// Get authorization header for API calls
  Map<String, String> getAuthHeaders() {
    return {
      'Authorization': 'Bearer ${currentState.token}',
      'Content-Type': 'application/json',
    };
  }

  /// Verify token is still valid and refresh if needed
  Future<bool> verifyToken() async {
    try {
      final token = currentState.token;
      if (token == null) return false;

      const projectId = 'roadsense-3e4b2';
      const region = 'asia-south1';
      const functionName = 'verifyToken';

      final response = await http.post(
        Uri.parse(
          'https://$region-$projectId.cloudfunctions.net/$functionName',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['valid'] == true;
      }

      return false;
    } catch (e) {
      print('Token verification failed: $e');
      return false;
    }
  }
}
