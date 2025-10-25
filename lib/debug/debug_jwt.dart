// lib/debug/debug_jwt.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';

void debugPrintJwtClaims(String? jwt) {
  if (jwt == null || jwt.isEmpty) return;
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return;
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    debugPrint('JWT payload => $payload');
  } catch (e) {
    debugPrint('JWT decode failed: $e');
  }
}
