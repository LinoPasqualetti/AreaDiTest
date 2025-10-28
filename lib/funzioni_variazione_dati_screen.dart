import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:data_table_2/data_table_2.dart';

import 'main.dart';

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

// FIX: Aggiunto il mixin per la permanenza dello stato
class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen> with AutomaticKeepAliveClientMixin {
  static const String _defaultQuery = """
select distinct percradice||percresto||Volume as PerApertura,Numpag,titolo,volume,ArchivioProvenienza, strumento,primolink, percradice,percresto 
from spartiti
where 
tipoMulti like 'PD%'
and titolo like 'chat%'
order by titolo,strumento
""";

  bool _isLoading = true;
  bool _isQueryRunning = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];
  List<String> _tableFields = [];

  final TextEditingController _sqlController = TextEditingController(
    text: _defaultQuery,
  );

  // FIX: Override della proprietà del mixin
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTableInfo();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _loadTableInfo() async {
    if (gDatabase == null) {
      setState(() {
        _error = "Database non disponibile. Controllare l'errore all'avvio.";
        _isLoading = false;
      });
      return;
    }
    try {
      final tableInfo = await gDatabase!.rawQuery('PRAGMA table_info(spartiti);');
      final fields = tableInfo.map((row) => row['name'] as String).toList();
      if (mounted) {
        setState(() {
          _tableFields = fields;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore nel leggere la struttura della tabella: \n${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeQuery() async {
    if (gDatabase == null || _isQueryRunning) return;
    setState(() { _isQueryRunning = true; _error = null; });
    try {
      final results = await gDatabase!.rawQuery(_sqlController.text);
      if (mounted) setState(() { _queryResults = results; _isQueryRunning = false; });
    } catch (e) {
      if (mounted) setState(() { _error = "Errore esecuzione query: \n${e.toString()}"; _queryResults = []; _isQueryRunning = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Chiamata a super.build() per il mixin
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && gDatabase == null) {
       return Center(child: SelectableText(_error!, style: const TextStyle(color: Colors.red)));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Text("Database corrente: $gDatabaseName", style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
           const SizedBox(height: 10),
          TextField(
            controller: _sqlController,
            maxLines: 7,
            decoration: const InputDecoration(labelText: 'Comando SQL', border: OutlineInputBorder()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildQueryControls(),
          const Divider(),
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isQueryRunning ? null : _executeQuery,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Esegui Query'),
            ),
            const SizedBox(width: 16),
            if (!_isQueryRunning && _queryResults.isNotEmpty)
              Text('Trovati: ${_queryResults.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        if (_tableFields.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Campi disponibili:'),
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6.0,
                runSpacing: 2.0,
                children: _tableFields.map((field) => ActionChip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  label: Text(field, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: field));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copiato: $field'), duration: const Duration(seconds: 1)));
                  },
                )).toList(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isQueryRunning) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: SelectableText(_error!, style: const TextStyle(color: Colors.red)));
    if (_queryResults.isEmpty) return const Center(child: Text('Nessun risultato o query non ancora eseguita.'));

    final columnKeys = _queryResults.first.keys.toList();
    return DataTable2(
      columnSpacing: 10,
      horizontalMargin: 10,
      minWidth: 2000,
      columns: columnKeys.map((key) {
        ColumnSize size;
        switch (key.toLowerCase()) {
          case 'perapertura': size = ColumnSize.M; break;
          case 'numpag': size = ColumnSize.S; break;
          case 'titolo': size = ColumnSize.L; break;
          default: size = ColumnSize.M;
        }
        return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: size);
      }).toList(),
      rows: _queryResults.map((row) {
        return DataRow(cells: row.values.map((cell) => DataCell(SelectableText(cell?.toString() ?? 'NULL', style: const TextStyle(fontSize: 11)))).toList());
      }).toList(),
    );
  }
}
