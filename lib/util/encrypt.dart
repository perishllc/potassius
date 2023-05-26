import 'dart:typed_data';

import 'package:pointycastle/api.dart' show ParametersWithIV, KeyParameter;
import 'package:pointycastle/stream/salsa20.dart';
import 'package:flutter_nano_ffi/flutter_nano_ffi.dart';

/**
 * Encryption using Salsa20 from pointycastle
 */
class Salsa20Encryptor {

  Salsa20Encryptor(this.key, this.iv)
      : _params = ParametersWithIV<KeyParameter>(
            KeyParameter(Uint8List.fromList(key.codeUnits)),
            Uint8List.fromList(iv.codeUnits));
            
  final String key;
  final String iv;
  final ParametersWithIV<KeyParameter> _params;
  final Salsa20Engine _cipher = Salsa20Engine();

  String encrypt(String plainText) {
    _cipher
      ..reset()
      ..init(true, _params);

    final Uint8List input = Uint8List.fromList(plainText.codeUnits);
    final Uint8List output = _cipher.process(input);

    return NanoHelpers.byteToHex(output);
  }

  String decrypt(String cipherText) {
    _cipher
      ..reset()
      ..init(false, _params);

    final Uint8List input = NanoHelpers.hexToBytes(cipherText);
    final Uint8List output = _cipher.process(input);

    return String.fromCharCodes(output);
  }
}