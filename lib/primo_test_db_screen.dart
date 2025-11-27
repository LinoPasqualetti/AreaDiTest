/////           primo_test_db_screen.dart    ////
//////       emette una lista dei db e delle tabelle del sistema
library;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';

import 'package:area_di_test/database_utils.dart';
import 'package:area_di_test/main.dart'; // Import per accedere alle variabili globali

class PrimoTestDbScreen extends StatefulWidget {
  const PrimoTestDbScreen({super.key});

  @override
  State<PrimoTestDbScreen> createState() => _PrimoTestDbScreenState();
}

class _PrimoTestDbScreenState extends State<PrimoTestDbScreen> {
  bool _isLoading = true;
  String? _error;

  Database? _dbGlobale;
  static const String _dbGlobaleName = 'DBGlobale_seed.db';

  List<Map<String, dynamic>> _datiSistemaApp = [];
  List<Map<String, dynamic>> _elencoCataloghi = [];
  // FIX: Rinominate le variabili per riflettere il catalogo attivo
  final Map<String, List<Map<String, dynamic>>> _activeCatalogData = {};
  String _dbGlobalePath = '';
  String _activeCatalogPath = '';

  @override
  void initState() {
    super.initState();
    _initAndLoadData();
  }

  @override
  void dispose() {
    _dbGlobale?.close();
    super.dispose();
  }

  Future<void> _initAndLoadData() async {
    try {
      _dbGlobale = await initDatabase(_dbGlobaleName);
      _dbGlobalePath = _dbGlobale!.path;
      _datiSistemaApp = await _dbGlobale!.query('DatiSistremaApp');
      _elencoCataloghi = await _dbGlobale!.query('elenco_cataloghi');

      // Usa il gDatabase globale che è già stato impostato sul catalogo attivo
      if (gDatabase != null && gDatabase!.isOpen) {
        _activeCatalogPath = gDatabase!.path;
        final tables = await gDatabase!.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
        for (var table in tables) {
          final tableName = table['name'] as String;
          if (tableName.startsWith('sqlite_')) continue;
          // FIX: Popola la mappa dei dati del catalogo attivo
          _activeCatalogData[tableName] = await gDatabase!.query(tableName, limit: 5);
        }
      } else {
        throw Exception('Database del catalogo attivo non è disponibile.');
      }

      if (mounted) {
        setState(() => _isLoading = false);
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
          // FIX: Titolo dinamico con il nome del DB attivo
          child: Text('Catalogo Attivo: $gActiveCatalogDbName - Prime 5 righe', style: Theme.of(context).textTheme.headlineSmall),
        ),
        for (var entry in _activeCatalogData.entries) ...[
          _buildDataTable(entry.key, entry.value, dbPath: _activeCatalogPath),
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

    const double headingRowHeight = 32;
    const double dataRowHeight = 32;

    final columns = data.first.keys.map((key) {
      ColumnSize size;
      final keyLower = key.toLowerCase();
      
      if (keyLower.endsWith('id') || keyLower == 'id_catalogo_attivo') {
        size = ColumnSize.S;
      } else if (keyLower.contains('percorso') || keyLower.contains('path') || keyLower.contains('nome') || keyLower.contains('titolo') || keyLower.contains('file')) {
        size = ColumnSize.L;
      } else {
        size = ColumnSize.M;
      }

      return DataColumn2(
        label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        size: size,
      );
    }).toList();

    final rows = data.map((row) {
      return DataRow(cells: row.values.map((cell) {
        return DataCell(SelectableText(cell?.toString() ?? 'NULL', style: const TextStyle(fontSize: 10)));
      }).toList());
    }).toList();

    final double tableHeight = headingRowHeight + (data.length * dataRowHeight) + 1;

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
          SizedBox(
            height: tableHeight,
            child: DataTable2(
              columnSpacing: 10,
              horizontalMargin: 10,
              minWidth: 1500, 
              headingRowHeight: headingRowHeight,
              dataRowHeight: dataRowHeight,
              columns: columns,
              rows: rows,
            ),
          ),
        ],
      ),
    );
  }
}
