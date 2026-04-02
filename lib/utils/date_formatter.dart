import 'package:flutter/services.dart'; // Make sure this is at the top of the file

// MAGIC AUTO-FORMATTER FOR DD/MM/YYYY
class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // 1. Remove everything except numbers
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 2. Cap it at 8 digits (DDMMYYYY)
    if (text.length > 8) text = text.substring(0, 8);

    // 3. Inject the slashes automatically
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '/';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length), // Keeps cursor at the end
    );
  }
}