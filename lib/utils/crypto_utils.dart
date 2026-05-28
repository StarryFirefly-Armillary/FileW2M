import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CryptoUtils {
  static Future<String> computeFileSha256(String filePath) async {
    final file = File(filePath);
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  static String computeStringSha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
