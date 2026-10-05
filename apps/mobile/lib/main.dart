import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'theme.dart';
import 'profile.dart';
import 'place_detail.dart';
const apiBase = 'http://192.168.0.140:3001';


void main() => runApp(const AppFrita());

class AppFrita extends StatelessWidget {
  const AppFrita({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppFrita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false;
  String? _error;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final err = _register
        ? await AuthApi.register(_name.text, _email.text, _pass.text)
        : await AuthApi.login(_email.text, _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else if (_register) {
      setState(() { _register = false; _error = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada, inicia sesión')));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Crear cuenta' : 'Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_register) TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email o teléfono')),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña (mín. 8)')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? '…' : (_register ? 'Registrarme' : 'Entrar')),
            ),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? 'Ya tengo cuenta' : 'Crear cuenta nueva'),
            ),
          ],
        ),
      ),
    );
  }
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<dynamic> _places = [];
  String _status = 'cargando…';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$apiBase/locations/nearby?lng=-66.9&lat=10.48&radius_m=5000'));
      if (r.statusCode == 200) {
        setState(() {
          _places = jsonDecode(r.body);
          _status = _places.isEmpty ? 'Nada abierto cerca' : '${_places.length} locales';
        });
      } else {
        setState(() => _status = 'Error ${r.statusCode}');
      }
    } catch (_) {
      setState(() => _status = 'Sin conexión a la API');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abiertos cerca'), actions: [IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())))]),
      body: _places.isEmpty
          ? Center(child: Text(_status))
          : ListView.builder(
              itemCount: _places.length,
              itemBuilder: (_, i) {
                final p = _places[i];
                return ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceDetailScreen(businessId: p['business_id'] ?? '', locationId: p['id'], name: p['name'] ?? ''))),
                  leading: const Icon(Icons.store, color: AppTheme.tertiary),
                  title: Text(p['name'] ?? ''),
                  subtitle: Text('${p['business_name'] ?? ''} · ${p['dist_m']?.toStringAsFixed(0)} m'),
                  trailing: Text('★ ${p['rating_avg']}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: _load, child: const Icon(Icons.refresh)),
    );
  }
}
