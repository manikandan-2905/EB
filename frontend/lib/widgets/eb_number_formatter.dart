library;

import 'package:flutter/services.dart';

/// Formats consumer EB number into xx-xxx-xxx-xxx automatically as digits are typed.
class EbNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only keep numeric digits
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    // Apply xx-xxx-xxx-xxx pattern (max 11 digits: 2 + 3 + 3 + 3)
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 2 || i == 5 || i == 8) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

