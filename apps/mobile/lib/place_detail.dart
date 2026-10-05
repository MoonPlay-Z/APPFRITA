import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';

const apiBase = 'http://192.168.0.140:3001';

class PlaceDetailScreen extends StatefulWidget {
  final String businessId;
  final String locationId;
  final String name;
  const PlaceDetailScreen({super.key, required this.businessId, required this.locationId, required this.name});
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  List<dynamic> _products = [];
  final Map<String, int> _cart = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await http.get(Uri.parse('$apiBase/catalog/products?business_id=${widget.businessId}'));
    if (r.statusCode == 200) setState(() => _products = jsonDecode(r.body));
  }

  double get _total => _cart.entries.fold(0.0, (s, e) {
        final p = _products.firstWhere((p) => p['id'] == e.key, orElse: () => null);
        return s + (p != null ? double.parse(p['price'].toString()) * e.value : 0);
      });

  Future<void> _checkout() async {
    final r = await http.post(Uri.parse('$apiBase/orders'),
        headers: {'content-type': 'application/json', 'Authorization': 'Bearer ${AuthApi.token}'},
        body: jsonEncode({
          'business_id': widget.businessId,
          'location_id': widget.locationId,
          'type': 'delivery',
          'items': _cart.entries.map((e) => {'product_id': e.key, 'quantity': e.value}).toList(),
        }));
    if (!mounted) return;
    if (r.statusCode == 200 || r.statusCode == 201) {
      final o = jsonDecode(r.body);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido ${o['code']} creado')));
      setState(() => _cart.clear());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ${r.statusCode}: ${r.body}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _products.isEmpty
          ? const Center(child: Text('Sin productos'))
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (_, i) {
                final p = _products[i];
                final qty = _cart[p['id']] ?? 0;
                return ListTile(
                  title: Text(p['name']),
                  subtitle: Text('\$${p['price']}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (qty > 0) IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _cart[p['id']] = qty - 1)),
                    if (qty > 0) Text('$qty'),
                    IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFAD2C00)), onPressed: () => setState(() => _cart[p['id']] = qty + 1)),
                  ]),
                );
              },
            ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _checkout,
                  child: Text('Pedir · \$${_total.toStringAsFixed(2)}'),
                ),
              ),
            ),
    );
  }
}
