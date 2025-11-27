import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';

import 'database_utils.dart';
import 'main.dart'; // Per riavviare l'app e gSpartitiTableName

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';
const String _primoVuotoName = 'PrimoVuoto.db';

/// Schermata per la prima installazione (setup) dei database dell'applicazione.
class AttivaDatieDB extends StatefulWidget {
  const AttivaDatieDB({super.key});

  @override
  State<AttivaDatieDB> createState() => _AttivaDatieDBState();
}

class _AttivaDatieDBState extends State<AttivaDatieDB> {
  final _formKey = GlobalKey<FormState>();
  final _percorsoPdfController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = "Pronto per l'installazione.";

  @override
  void dispose() {
    _percorsoPdfController.dispose();
    super.dispose();
  }

  /// Esegue la logica di setup: copia i DB master e crea il DB vuoto.
  Future<void> _runFirstTimeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await _updateStatus('Avvio installazione...');

    try {
      final supportDir = await getApplicationSupportDirectory();

      // Fase 1: Copia i DB esistenti dagli asset e crea quello vuoto
      await _updateStatus('1/3: Preparazione database...');
      await initDatabase(_dbGlobaleName);      // Copia DBGlobale_seed.db
      await initDatabase(_vecchioDbName);      // Copia VecchioDb.db (con 2 tabelle)

      // Crea PrimoVuoto.db da zero, con una sola tabella 'spartiti'
      final primoVuotoPath = p.join(supportDir.path, _primoVuotoName);
      if (await databaseExists(primoVuotoPath)) {
        await deleteDatabase(primoVuotoPath);
      }
      const createStatement = 'CREATE TABLE $gSpartitiTableName ( id_univoco_globale INTEGER UNIQUE, IdBra TEXT,titolo TEXT, autore TEXT,strumento TEXT, volume TEXT,PercRadice TEXT, PercResto TEXT, PrimoLInk  TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT,IdAutore TEXT, PRIMARY KEY (id_univoco_globale AUTOINCREMENT))';
      Database dbVuoto = await openDatabase(primoVuotoPath, version: 1, onCreate: (db, version) => db.execute(createStatement));
      await dbVuoto.close();

      // Fase 2: Apri il DB di configurazione e scrivi i valori di default
      await _updateStatus('2/3: Scrittura configurazione iniziale...');
      final dbGlobale = await databaseFactory.openDatabase(p.join(supportDir.path, _dbGlobaleName));
      
      await dbGlobale.delete('elenco_cataloghi');
      
      final batch = dbGlobale.batch();
      batch.insert('elenco_cataloghi', {
        'id': 1, 'nome_catalogo': 'Vecchio Catalogo Principale',
        'descrizione': 'Catalogo di default pre-caricato.', 'nome_file_db': _vecchioDbName
      });
      batch.insert('elenco_cataloghi', {
        'id': 2, 'nome_catalogo': 'Catalogo Vuoto di Esempio',
        'descrizione': 'Un catalogo vuoto per nuovi brani.', 'nome_file_db': _primoVuotoName
      });
      await batch.commit(noResult: true);

      await dbGlobale.update('DatiSistremaApp', {
        'PercorsoPdf': _percorsoPdfController.text,
        'id_catalogo_attivo': 1,
      });
      await dbGlobale.close();
      
      await _updateStatus('3/3: Installazione completata!');

      // Fase 3: Mostra messaggio e riavvia l'app
      if (mounted) {
        await showDialog(
          context: context, barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Installazione Completata'),
            content: const Text('L\'applicazione verrà ora riavviata per applicare le modifiche.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
        main(); // Riavvia l'app per ricaricare la configurazione
      }

    } catch (e) {
      await _updateStatus('ERRORE DI INSTALLAZIONE: \n$e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String message) async {
    if (!mounted) return;
    setState(() => _statusMessage = message);
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  Future<void> _pickFolder() async {
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        _percorsoPdfController.text = directoryPath;
        setState(() {});
      }
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore selezione cartella: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Iniziale Applicazione')),
      body: Center(
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(), 
                  const SizedBox(height: 24),
                  Text(_statusMessage, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center)
                ]),
              )
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             const Text(
              'Benvenuto! Esegui il setup per iniziare.',
              style: TextStyle(fontSize: 18), textAlign: TextAlign.center,
            ),
             const SizedBox(height: 12),
             const Text(
              'Verranno copiati i database iniziali e creato il catalogo vuoto.',
              style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _percorsoPdfController,
              decoration: InputDecoration(
                labelText: 'Percorso Radice PDF',
                border: const OutlineInputBorder(),
                helperText: 'La cartella principale dove si trovano i tuoi spartiti in PDF.',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickFolder,
                  tooltip: 'Seleziona cartella',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Questo campo è obbligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _runFirstTimeSetup,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('INIZIA INSTALLAZIONE'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
