import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Centralized debug logger for visitor API traffic.
abstract final class VisitorApiLogger {
  static const String tag = '[VisitorAPI]';

  /// When false (default), empty polling ticks are not logged spam.
  /// Set true if you need every poll request/response body.
  static bool verbosePolling = false;

  static void log(String message) {
    if (!kDebugMode) return;
    debugPrint('$tag $message');
  }

  static void request({
    required String method,
    required Uri url,
    Object? body,
    bool quiet = false,
  }) {
    if (!kDebugMode || quiet) return;
    final buffer = StringBuffer()
      ..writeln('$tag ── REQUEST ─────────────────────────')
      ..writeln('$tag $method $url');
    if (body != null) {
      buffer.writeln('$tag body: ${_pretty(body)}');
    }
    debugPrint(buffer.toString().trimRight());
  }

  static void response({
    required String method,
    required Uri url,
    required int statusCode,
    required String body,
    bool quiet = false,
  }) {
    if (!kDebugMode || quiet) return;
    final buffer = StringBuffer()
      ..writeln('$tag ── RESPONSE ────────────────────────')
      ..writeln('$tag $method $url')
      ..writeln('$tag status: $statusCode')
      ..writeln('$tag body: ${_prettyBody(body)}');
    debugPrint(buffer.toString().trimRight());
  }

  static void info(String message) => log(message);

  static void warn(String message) => log('⚠ $message');

  static void error(String message, [Object? cause]) {
    if (!kDebugMode) return;
    debugPrint('$tag ✖ $message${cause != null ? ' | cause=$cause' : ''}');
  }

  static String _pretty(Object value) {
    try {
      if (value is String) return _prettyBody(value);
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  static String _prettyBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '<empty>';
    try {
      final decoded = jsonDecode(trimmed);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      if (trimmed.length > 4000) {
        return '${trimmed.substring(0, 4000)}…(truncated)';
      }
      return trimmed;
    }
  }
}
