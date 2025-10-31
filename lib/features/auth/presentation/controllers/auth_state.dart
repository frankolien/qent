import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthState {
  final bool isLoading;
  final fb.User? user;
  final String? errorMessage;

  const AuthState({this.isLoading = false, this.user, this.errorMessage});

  AuthState copyWith({bool? isLoading, fb.User? user, String? errorMessage}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.initial() => const AuthState(isLoading: false, user: null, errorMessage: null);
}


