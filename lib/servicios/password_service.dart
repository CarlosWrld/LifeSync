import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class PasswordService {
  static Future<String> hash(String password) => compute(_hash, password);
  static Future<bool> verify(String password, String encoded) =>
      compute(_verify, [password, encoded]);
}

Future<List<int>> _derive(String password, List<int> salt) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  return key.extractBytes();
}

Future<String> _hash(String password) async {
  final random = Random.secure();
  final salt = List<int>.generate(16, (_) => random.nextInt(256));
  final hash = await _derive(password, salt);
  return 'pbkdf2-sha256:600000:${base64Encode(salt)}:${base64Encode(hash)}';
}

Future<bool> _verify(List<String> args) async {
  final parts = args[1].split(':');
  if (parts.length != 4 ||
      parts[0] != 'pbkdf2-sha256' ||
      parts[1] != '600000') {
    return false;
  }
  try {
    final actual = await _derive(args[0], base64Decode(parts[2]));
    final expected = base64Decode(parts[3]);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  } on FormatException {
    return false;
  }
}
