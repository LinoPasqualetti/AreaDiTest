/////////GestisciElencoCataloghi.dart emette la lista dei Db catalogo presenti
///// si può inserire o variare un db catalogo
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'VariaCatalogo.dart'; // 1. IMPORTA LA NUOVA SCHERMATA

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
      final data = await db.query('elenco_cataloghi', orderBy: 'nome_catalogo');
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

  // FIX: Passa il parametro mancante 'totalCataloghi'
  Future<void> _navigateToVariaScreen([Map<String, dynamic>? catalogo]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VariaCatalogoScreen(
          initialData: catalogo,
          totalCataloghi: _cataloghi.length, // Passa il numero totale di cataloghi
        ),
      ),
    );

    if (result == true) {
      _loadCataloghi();
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
            onPressed: () => _navigateToVariaScreen(),
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
      return const Center(child: Text('Nessun catalogo trovato. Premi + per aggiungerne uno.'));
    }

    return ListView.builder(
      itemCount: _cataloghi.length,
      itemBuilder: (context, index) {
        final catalogo = _cataloghi[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ListTile(
            isThreeLine: true,
            leading: CircleAvatar(child: Text(catalogo['id'].toString())),
            title: Text(catalogo['nome_catalogo']?.toString() ?? 'Senza nome', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${catalogo['nome_file_db']?.toString() ?? 'N/A'}'),
                Text('Brani: ${catalogo['conteggio_brani']?.toString() ?? '0'} - Ult. agg: ${catalogo['data_ultimo_aggiornamento']?.toString() ?? 'Mai'}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _navigateToVariaScreen(catalogo),
            ),
          ),
        );
      },
    );
  }
}
