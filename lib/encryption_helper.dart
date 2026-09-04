import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:convert/convert.dart';

class EncryptionHelper {
  final encrypt.Key key;
  final encrypt.IV iv;
  final encrypt.Encrypter encrypter;

  EncryptionHelper(String keyString)
      : key = encrypt.Key.fromUtf8(keyString.padRight(32, ' ')), // 32バイトにパディング
        iv = encrypt.IV.fromLength(16),
        encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key.fromUtf8(keyString.padRight(32, ' ')), mode: encrypt.AESMode.cbc));

  String encryptString(String plainText) {
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String decryptString(String encryptedText) {
    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
    return decrypted;
  }
}