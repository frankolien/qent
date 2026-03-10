import 'package:qent/features/auth/domain/models/auth_user.dart';

class AuthState {
  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;

  const AuthState({this.isLoading = false, this.user, this.errorMessage});

  AuthState copyWith({bool? isLoading, AuthUser? user, String? errorMessage, bool clearUser = false}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: errorMessage,
    );
  }

  factory AuthState.initial() => const AuthState(isLoading: false, user: null, errorMessage: null);
}
