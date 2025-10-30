import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:area_di_test/database_utils.dart';
import 'package:area_di_test/main.dart'; // Import per accedere a gDatabase

class PrimoTestDbScreen extends StatefulWidget {
  const PrimoTestDbScreen({super.key});

  @override
  State<PrimoTestDbScreen> createState() => _PrimoTestDbScreenState();
}

class _PrimoTestDbScreenState extends State<PrimoTestDbScreen> {
  bool _isLoading = true;
  String? _error;

  // DB locale, gestito da questo widget
  Database? _dbGlobale;
  static const String _dbGlobaleName = 'DBGlobale_seed.db';

  // Dati per la UI
  List<Map<String, dynamic>> _datiSistemaApp = [];
  List<Map<String, dynamic>> _elencoCataloghi = [];
  final Map<String, List<Map<String, dynamic>>> _vecchioDbData = {};
  String _dbGlobalePath = '';
  String _vecchioDbPath = '';

  @override
  void initState() {
    super.initState();
    _initAndLoadData();
  }

  @override
  void dispose() {
    // Chiude SOLO il DB locale quando lo screen viene distrutto
    _dbGlobale?.close();
    super.dispose();
  }

  Future<void> _initAndLoadData() async {
    try {
      // 1. Gestisce DBGlobale localmente
      _dbGlobale = await initDatabase(_dbGlobaleName);
      _dbGlobalePath = _dbGlobale!.path;
      _datiSistemaApp = await _dbGlobale!.query('DatiSistremaApp');
      _elencoCataloghi = await _dbGlobale!.query('elenco_cataloghi');

      // 2. Usa gDatabase per VecchioDB, senza aprirlo ne chiuderlo
      if (gDatabase != null && gDatabase!.isOpen) {
        _vecchioDbPath = gDatabase!.path;
        final tables = await gDatabase!.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
        for (var table in tables) {
          final tableName = table['name'] as String;
          if (tableName.startsWith('sqlite_')) continue;
          _vecchioDbData[tableName] = await gDatabase!.query(tableName, limit: 3);
        }
      } else {
        throw Exception('Database globale (VecchioDb) non è disponibile.');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        _buildDataTable('DatiSistremaApp', _datiSistemaApp, dbPath: _dbGlobalePath),
        const SizedBox(height: 16),
        _buildDataTable('elenco_cataloghi', _elencoCataloghi, dbPath: _dbGlobalePath),
        const SizedBox(height: 16),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text('VecchioDB - Prime 3 righe', style: Theme.of(context).textTheme.headlineSmall),
        ),
        for (var entry in _vecchioDbData.entries) ...[
          _buildDataTable(entry.key, entry.value, dbPath: _vecchioDbPath),
          const SizedBox(height: 16),
        ]
      ],
    );
  }

  Widget _buildDataTable(String title, List<Map<String, dynamic>> data, {String? dbPath}) {
    if (data.isEmpty) {
      return Card(
          child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Nessun dato trovato.'),
      ));
    }

    final columns = data.first.keys.map((key) => DataColumn(label: Text(key))).toList();
    final rows = data.map((row) {
      return DataRow(
          cells: row.values.map((cell) {
        return DataCell(SelectableText(cell?.toString() ?? 'NULL'));
      }).toList());
    }).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  if (dbPath != null && dbPath.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(dbPath, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]))
                  ]
                ],
              )),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: columns, rows: rows),
          ),
        ],
      ),
    );
  }
}
