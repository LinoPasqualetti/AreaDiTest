import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';

import 'database_utils.dart';
import 'main.dart'; // Per la variabile globale gSpartitiTableName

class ListaSpartitiCatalogoScreen extends StatefulWidget {
  final int catalogoId;
  final String nomeCatalogo;
  final String dbName; // Parametro aggiunto

  const ListaSpartitiCatalogoScreen({
    super.key,
    required this.catalogoId,
    required this.nomeCatalogo,
    required this.dbName,
  });

  @override
  State<ListaSpartitiCatalogoScreen> createState() => _ListaSpartitiCatalogoScreenState();
}

class _ListaSpartitiCatalogoScreenState extends State<ListaSpartitiCatalogoScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _spartiti = [];

  @override
  void initState() {
    super.initState();
    _loadSpartiti();
  }

  Future<void> _loadSpartiti() async {
    print('--- Inizio operazione DB: _loadSpartiti (Catalogo: ${widget.dbName}) ---');
    try {
      final Database db = await initDatabase(widget.dbName);
      print('[OK] DB ${widget.dbName} APERTO');
      print('Eseguo QUERY su $gSpartitiTableName...');
      final data = await db.query(gSpartitiTableName, limit: 50);
      print('[OK] Trovati ${data.length} record.');
      await db.close();

      if (mounted) {
        setState(() {
          _spartiti = data;
          _isLoading = false;
        });
      }
    } catch (e) {
       print('--- ERRORE operazione DB: _loadSpartiti ---\n$e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
       print('--- Fine operazione DB: _loadSpartiti ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spartiti in: ${widget.nomeCatalogo}'),
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
    if (_spartiti.isEmpty) {
      return const Center(child: Text('Nessuno spartito trovato in questo catalogo.'));
    }

    final columns = _spartiti.first.keys.map((key) {
      return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)));
    }).toList();

    final rows = _spartiti.map((row) {
      return DataRow(cells: row.values.map((cell) {
        return DataCell(SelectableText(cell?.toString() ?? 'NULL'));
      }).toList());
    }).toList();

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 12,
      minWidth: 1500,
      columns: columns,
      rows: rows,
    );
  }
}
