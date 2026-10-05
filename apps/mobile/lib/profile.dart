import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';

const apiBase = 'http://192.168.0.140:3001';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$apiBase/auth/me'),
          headers: {'Authorization': 'Bearer ${AuthApi.token}'});
      if (r.statusCode == 200) {
        setState(() => _me = jsonDecode(r.body));
      } else {
        setState(() => _error = 'Error ${r.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Sin conexión');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _me == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 32)),
                      const SizedBox(height: 16),
                      Text(_me!['full_name'] ?? '', style: Theme.of(context).textTheme.headlineSmall),
                      Text(_me!['email'] ?? _me!['phone'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      Text('Rol: ${_me!['role']}'),
                      const Spacer(),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { AuthApi.token = null; Navigator.of(context).popUntil((r) => r.isFirst); }, child: const Text('Cerrar sesión'))),
                    ],
                  ),
                ),
    );
  }
}
