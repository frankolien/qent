import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Maps an exception to a user-safe message. Raw error + stack go to debug logs.
String friendlyError(Object error, {String tag = 'App', StackTrace? stack}) {
  if (kDebugMode) {
    debugPrint('[Qent $tag] $error');
    if (stack != null) debugPrint('$stack');
  }

  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is TimeoutException) {
    return 'The server is taking too long. Try again in a moment.';
  }
  if (error is HttpException) {
    return 'Couldn\'t reach the server. Please try again.';
  }
  if (error is FormatException) {
    return 'Something went wrong. Please try again.';
  }

  final msg = error.toString();
  final lower = msg.toLowerCase();

  if (lower.contains('invalid credentials') ||
      lower.contains('wrong password') ||
      lower.contains('incorrect password')) {
    return 'Wrong email or password.';
  }
  if (lower.contains('user not found') || lower.contains('no such user')) {
    return 'No account found with that email.';
  }
  if (lower.contains('already exists') || lower.contains('duplicate')) {
    return 'An account with this email already exists.';
  }
  if (lower.contains('email not verified')) {
    return 'Please verify your email first.';
  }
  if (lower.contains('unauthorized') || lower.contains('401')) {
    return 'Session expired. Please sign in again.';
  }
  if (lower.contains('forbidden') || lower.contains('403')) {
    return 'You don\'t have access to do that.';
  }
  if (lower.contains('not found') || lower.contains('404')) {
    return 'That item could not be found.';
  }
  if (lower.contains('too many requests') || lower.contains('429')) {
    return 'You\'re going too fast. Please slow down and try again.';
  }
  if (lower.contains('internal server') || lower.contains('500')) {
    return 'Server hiccup. Please try again shortly.';
  }
  if (lower.contains('host is down') ||
      lower.contains('connection refused') ||
      lower.contains('connection failed')) {
    return 'Can\'t reach the server. Check your connection.';
  }

  return 'Something went wrong. Please try again.';
}
