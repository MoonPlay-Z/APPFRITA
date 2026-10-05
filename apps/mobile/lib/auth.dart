import 'dart:convert';
import 'package:http/http.dart' as http;

const apiBase = 'http://192.168.0.140:3001';

class AuthApi {
  static String? token;

  static Future<String?> login(String identifier, String password) async {
    final r = await http.post(Uri.parse('$apiBase/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}));
    if (r.statusCode == 200 || r.statusCode == 201) {
      token = jsonDecode(r.body)['access_token'];
      return null;
    }
    return jsonDecode(r.body)['message']?.toString() ?? 'Error ${r.statusCode}';
  }

  static Future<String?> register(String name, String email, String password) async {
    final r = await http.post(Uri.parse('$apiBase/auth/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'full_name': name, 'email': email, 'password': password}));
    if (r.statusCode == 200 || r.statusCode == 201) return null;
    return jsonDecode(r.body)['message']?.toString() ?? 'Error ${r.statusCode}';
  }
}
