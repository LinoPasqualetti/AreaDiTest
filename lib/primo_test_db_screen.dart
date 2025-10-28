import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

// Importa il nostro file "ponte" che sceglie l'implementazione giusta.
import 'package:area_di_test/database_utils.dart';

class PrimoTestDbScreen extends StatefulWidget {
  const PrimoTestDbScreen({super.key});

  @override
  State<PrimoTestDbScreen> createState() => _PrimoTestDbScreenState();
}

class _PrimoTestDbScreenState extends State<PrimoTestDbScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _datiSistemaApp = [];
  List<Map<String, dynamic>> _elencoCataloghi = [];

  static const String _dbName = 'DBGlobale_seed.db';

  @override
  void initState() {
    super.initState();
    _initAndLoadData();
  }

  Future<void> _initAndLoadData() async {
    try {
      // Questa funzione `initDatabase` è ora multi-piattaforma grazie al nostro file ponte.
      final db = await initDatabase(_dbName);

      final datiSistema = await db.query('DatiSistremaApp');
      final cataloghi = await db.query('elenco_cataloghi');
      
      await db.close();

      if (mounted) {
        setState(() {
          _datiSistemaApp = datiSistema;
          _elencoCataloghi = cataloghi;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore durante il caricamento del database: \n${e.toString()}';
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
          child: SelectableText(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        _buildDataTable('DatiSistremaApp', _datiSistemaApp),
        const SizedBox(height: 16),
        _buildDataTable('elenco_cataloghi', _elencoCataloghi),
      ],
    );
  }

  Widget _buildDataTable(String title, List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Card(
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Nessun dato trovato.'),
        ),
      );
    }

    final columns = data.first.keys.map((key) => DataColumn(label: Text(key))).toList();
    final rows = data.map((row) {
      return DataRow(
          cells: row.values.map((cell) {
        return DataCell(SelectableText(cell.toString()));
      }).toList());
    }).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: columns,
              rows: rows,
            ),
          ),
        ],
      ),
    );
  }
}
