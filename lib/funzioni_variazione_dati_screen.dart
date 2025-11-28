//// funzioni_variazione_dati_screen.dart
/////ricerca fts su spartiti con filtri e apertura pdf
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import 'main.dart';
import 'platform/opener_platform_interface.dart'; 

/// Schermata di ricerca avanzata per gli spartiti.
class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen> with AutomaticKeepAliveClientMixin {
  bool _isQueryRunning = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];
  
  Duration? _dbQueryTime;
  Duration? _uiBuildTime;

  // Controller per i campi di ricerca
  late final TextEditingController _ricercaController;
  late final TextEditingController _strumentoController;
  late final TextEditingController _volumeController;
  late final TextEditingController _provenienzaController;
  late final TextEditingController _tipoMultiController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ricercaController = TextEditingController();
    _strumentoController = TextEditingController();
    _volumeController = TextEditingController();
    _provenienzaController = TextEditingController();
    _tipoMultiController = TextEditingController();
  }

  @override
  void dispose() {
    _ricercaController.dispose();
    _strumentoController.dispose();
    _volumeController.dispose();
    _provenienzaController.dispose();
    _tipoMultiController.dispose();
    super.dispose();
  }

  Future<void> _executeQuery() async {
    if (gDatabase == null || _isQueryRunning) return;
    
    setState(() { 
      _isQueryRunning = true; 
      _error = null; 
      _dbQueryTime = null;
      _uiBuildTime = null;
    });
    
    try {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (_ricercaController.text.isNotEmpty) {
        whereClauses.add('spartiti_fts MATCH ?');
        whereArgs.add('"${_ricercaController.text}"');
      }
      if (_tipoMultiController.text.isNotEmpty) {
        whereClauses.add('a.tipoMulti LIKE ?');
        whereArgs.add(_tipoMultiController.text);
      }
      if (_volumeController.text.isNotEmpty) {
        whereClauses.add('a.volume LIKE ?');
        whereArgs.add(_volumeController.text);
      }
      if (_provenienzaController.text.isNotEmpty) {
        whereClauses.add('a.ArchivioProvenienza LIKE ?');
        whereArgs.add(_provenienzaController.text);
      }
      if (_strumentoController.text.isNotEmpty) {
        whereClauses.add('a.strumento LIKE ?');
        whereArgs.add(_strumentoController.text);
      }

      String whereStatement = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

      final sanitizedPercorsoPdf = gPercorsoPdf.replaceAll("'", "''");

      // FIX: Usa la query fornita dall'utente che definisce l'ordine e la formattazione corretti
      final sql = """
        select distinct
          a.titolo,
          printf('%-7.7s', CAST(Numpag AS TEXT)) as Numpag,
          a.volume,
          a.ArchivioProvenienza,
          printf('%-7.7s', a.strumento) as strumento,
          primolink,
          '$sanitizedPercorsoPdf' as percradice,
          '$sanitizedPercorsoPdf'||percresto||a.volume as PerApertura,
          percresto
        from $gSpartitiTableName a
        JOIN spartiti_fts fts on a.idBra=fts.rowid
        $whereStatement
        order by a.titolo, a.strumento
      """;

      final dbStopwatch = Stopwatch()..start();
      final results = await gDatabase!.rawQuery(sql, whereArgs);
      dbStopwatch.stop();

      if (mounted) {
        final uiStopwatch = Stopwatch()..start();
        setState(() { 
          _queryResults = results; 
          _isQueryRunning = false; 
          _dbQueryTime = dbStopwatch.elapsed;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _uiBuildTime = uiStopwatch.elapsed);
            }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _error = "Errore esecuzione query: ${e.toString()}"; 
          _queryResults = []; 
          _isQueryRunning = false; 
        });
      }
    }
  }

  Future<void> _openPdfFromRow(Map<String, dynamic> rowData) async {
    final lowerCaseRowData = {for (var k in rowData.keys) k.toLowerCase(): rowData[k]};

    if (!lowerCaseRowData.containsKey('perapertura') || !lowerCaseRowData.containsKey('numpag')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: La query deve contenere le colonne "PerApertura" e "Numpag".'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final filePath = lowerCaseRowData['perapertura'] as String?;
    final pageNum = lowerCaseRowData['numpag'];

    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ERRORE: Il percorso del file (PerApertura) è vuoto o nullo.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final page = int.tryParse(pageNum?.toString().trim() ?? '1') ?? 1;

    await OpenerPlatformInterface.instance.openPdf(
      context: context,
      filePath: filePath,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             _buildSearchPanel(),
             const SizedBox(height: 10),
             _buildQueryControls(),
             const Divider(),
             Expanded(
               child: _buildResultsSection(),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ricerca Testuale (FTS)', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _ricercaController,
          decoration: const InputDecoration(
            hintText: 'Es: girl ipanema', 
            border: OutlineInputBorder(),
            isDense: true, 
          ),
        ),
        const SizedBox(height: 8),
        const Text('Filtri (usare % per wildcard LIKE)', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: _buildFilterField(_strumentoController, 'Strumento')),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterField(_volumeController, 'Volume')),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterField(_provenienzaController, 'Provenienza')),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterField(_tipoMultiController, 'TipoMulti')),
          ],
        )
      ],
    );
  }

  Widget _buildFilterField(TextEditingController controller, String label) {
    return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
        ),
      );
  }

  Widget _buildQueryControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _isQueryRunning ? null : _executeQuery,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Esegui Query'),
        ),
        const SizedBox(height: 2),
        if (!_isQueryRunning && _queryResults.isNotEmpty)
          Text('Trovati: ${_queryResults.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (_dbQueryTime != null) 
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text('Tempo Query DB: ${_dbQueryTime!.inMilliseconds} ms', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        if (_uiBuildTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text('Tempo UI: ${_uiBuildTime!.inMilliseconds} ms', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isQueryRunning) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: SelectableText(_error!, style: const TextStyle(color: Colors.red)));
    if (_queryResults.isEmpty) return const Center(child: Text('Nessun risultato. Esegui una ricerca.'));

    final columnKeys = _queryResults.first.keys.toList();
    return DataTable2(
      columnSpacing: 10,
      horizontalMargin: 10,
      minWidth: 2000,
      columns: columnKeys.map((key) {
        return DataColumn2(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
      }).toList(),
      rows: _queryResults.map((row) {
        return DataRow2(
          onTap: () => _openPdfFromRow(row),
          cells: row.values.map((cell) => DataCell(Text(
            cell?.toString() ?? 'NULL',
            style: const TextStyle(fontFamily: 'monospace'), // FIX: Usa un font monospazio
          ))).toList(),
        );
      }).toList(),
    );
  }
}
