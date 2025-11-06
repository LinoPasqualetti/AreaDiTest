import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String _dbGlobaleName = 'DBGlobale_seed.db';

class GestisciElencoCataloghi extends StatefulWidget {
  const GestisciElencoCataloghi({super.key});

  @override
  State<GestisciElencoCataloghi> createState() => _GestisciElencoCataloghiState();
}

class _GestisciElencoCataloghiState extends State<GestisciElencoCataloghi> {
  List<Map<String, dynamic>> _cataloghi = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCataloghi();
  }

  Future<void> _loadCataloghi() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dbPath = p.join(supportDir.path, _dbGlobaleName);
      Database db = await openDatabase(dbPath);
      final data = await db.query('elenco_cataloghi');
      await db.close();

      if (mounted) {
        setState(() {
          _cataloghi = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Elenco Cataloghi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () { /* TODO: Logica per aggiungere nuovo catalogo */ },
            tooltip: 'Nuovo Catalogo',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: SelectableText('Errore: $_error')));
    }
    if (_cataloghi.isEmpty) {
      return const Center(child: Text('Nessun catalogo trovato.'));
    }

    return ListView.builder(
      itemCount: _cataloghi.length,
      itemBuilder: (context, index) {
        final catalogo = _cataloghi[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ListTile(
            title: Text(catalogo['NomeCatalogo']?.toString() ?? 'Senza nome'),
            subtitle: Text('File: ${catalogo['nome_file_db']?.toString() ?? 'N/A'}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () { /* TODO: Logica per modificare catalogo */ },
            ),
          ),
        );
      },
    );
  }
}
