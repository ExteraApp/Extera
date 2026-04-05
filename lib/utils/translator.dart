import 'dart:convert';

import 'package:http/http.dart' as http;

class Translator {
  static Future<String> translate(
    String str,
    String targetLanguage,
    String baseUrl,
  ) async {
    final url = Uri.parse('$baseUrl/translate/anything/auto/$targetLanguage');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': str}),
    );
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['text'] ?? '';
    } else {
      throw Exception('Failed to translate text: ${response.statusCode}');
    }
  }
}
