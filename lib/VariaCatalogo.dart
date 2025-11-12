import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'database_utils.dart';
import 'lista_spartiti_catalogo.dart'; // Importa la schermata finale

const String _dbGlobaleName = 'DBGlobale_seed.db';

class VariaCatalogoScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final int totalCataloghi;

  const VariaCatalogoScreen({super.key, this.initialData, required this.totalCataloghi});

  @override
  State<VariaCatalogoScreen> createState() => _VariaCatalogoScreenState();
}

class _VariaCatalogoScreenState extends State<VariaCatalogoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isNewRecord = true;

  @override
  void initState() {
    super.initState();
    _isNewRecord = widget.initialData == null;
    
    _controllers = {
      'id': TextEditingController(),
      'nome_catalogo': TextEditingController(),
      'descrizione': TextEditingController(), 
      'nome_file_db': TextEditingController(),
      'FilesPath': TextEditingController(),
      'AppPath': TextEditingController(),
      'data_creazione': TextEditingController(),
      'data_ultimo_aggiornamento': TextEditingController(),
      'conteggio_brani': TextEditingController(),
    };

    if (!_isNewRecord) {
      widget.initialData!.forEach((key, value) {
        _controllers[key]?.text = value?.toString() ?? '';
      });
    } else {
       _controllers['data_creazione']?.text = DateTime.now().toIso8601String();
       _controllers['conteggio_brani']?.text = '0';
    }
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    print('--- Inizio operazione DB: _saveData ---');
    try {
      final db = await openDatabase(p.join((await getApplicationSupportDirectory()).path, _dbGlobaleName));
      print('[OK] DB GLOABLE APERTO');
      
      Map<String, dynamic> dataToSave = {};
      _controllers.forEach((key, controller) => dataToSave[key] = controller.text);
      dataToSave['data_ultimo_aggiornamento'] = DateTime.now().toIso8601String();

      if (_isNewRecord) {
        print('Eseguo INSERT su elenco_cataloghi...');
        dataToSave.remove('id');
        await db.insert('elenco_cataloghi', dataToSave, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        print('Eseguo UPDATE su elenco_cataloghi (ID: ${dataToSave['id']})...');
        await db.update('elenco_cataloghi', dataToSave, where: 'id = ?', whereArgs: [dataToSave['id']]);
      }
      print('[OK] Operazione completata');

      await db.close();
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dati salvati con successo!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
       print('--- ERRORE operazione DB: _saveData ---\n$e');
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      print('--- Fine operazione DB: _saveData ---');
    }
  }

  Future<void> _deleteData() async {
    if (_isNewRecord || widget.initialData == null) return;

    final id = widget.initialData!['id'];
    if (id == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRORE: Il catalogo di default (ID 1) non può essere eliminato.'), backgroundColor: Colors.red));
      return;
    }
    if (widget.totalCataloghi <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ERRORE: Non puoi eliminare l\'ultimo catalogo rimasto.'), backgroundColor: Colors.red));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Sei sicuro di voler eliminare il catalogo "${widget.initialData!['nome_catalogo']}"? L\'operazione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      print('--- Inizio operazione DB: _deleteData ---');
      try {
        final db = await openDatabase(p.join((await getApplicationSupportDirectory()).path, _dbGlobaleName));
        print('[OK] DB GLOABLE APERTO');
        print('Eseguo DELETE su elenco_cataloghi (ID: $id)...');
        await db.delete('elenco_cataloghi', where: 'id = ?', whereArgs: [id]);
        print('[OK] Operazione completata');
        await db.close();
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalogo eliminato.'), backgroundColor: Colors.orange));
            Navigator.of(context).pop(true);
        }
      } catch (e) {
          print('--- ERRORE operazione DB: _deleteData ---\n$e');
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      } finally {
         print('--- Fine operazione DB: _deleteData ---');
      }
    }
  }

  Future<void> _pickFolder(String controllerKey) async {
    String? initialDir;
    if (controllerKey == 'FilesPath') {
      initialDir = (await getApplicationSupportDirectory()).path;
    }
    
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath(initialDirectory: initialDir);
      if (directoryPath != null) {
        _controllers[controllerKey]?.text = directoryPath;
        setState(() {});
      }
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore selezione cartella: $e')));
    }
  }

  Future<void> _verificaEApriCatalogo() async {
    final dbName = _controllers['nome_file_db']?.text;
    if (dbName == null || dbName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome file DB non specificato.'), backgroundColor: Colors.red));
      return;
    }

    print('--- Inizio operazione DB: _verificaEApriCatalogo ---');
    try {
      print('Chiamo initDatabase per "$dbName"...');
      await initDatabase(dbName);
      print('[OK] initDatabase per "$dbName" completato.');

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database "$dbName" verificato e pronto.'), backgroundColor: Colors.blue));
         Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ListaSpartitiCatalogoScreen(
              catalogoId: int.parse(_controllers['id']!.text),
              nomeCatalogo: _controllers['nome_catalogo']!.text,
              dbName: dbName, // <- Questo causera un errore se l'altro file non è aggiornato
            ),
          ),
        );
      }

    } catch (e) {
       print('--- ERRORE operazione DB: _verificaEApriCatalogo ---\n$e');
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante la verifica del DB: $e')));
    } finally {
      print('--- Fine operazione DB: _verificaEApriCatalogo ---');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewRecord ? 'Nuovo Catalogo' : 'Varia Catalogo'),
        actions: [
          if (!_isNewRecord)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteData,
              tooltip: 'Elimina Catalogo',
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._controllers.entries.map((entry) {
                final key = entry.key;
                final controller = entry.value;
                bool isReadOnly = ['id', 'data_creazione', 'data_ultimo_aggiornamento', 'conteggio_brani'].contains(key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: controller,
                    readOnly: isReadOnly,
                    maxLines: key == 'descrizione' ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: key,
                      border: const OutlineInputBorder(),
                      filled: isReadOnly,
                      fillColor: isReadOnly ? Colors.grey[200] : null,
                      suffixIcon: (key == 'FilesPath' || key == 'AppPath') ? IconButton(icon: const Icon(Icons.folder_open), onPressed: () => _pickFolder(key)) : null,
                    ),
                    validator: (value) {
                      if (!isReadOnly && (value == null || value.isEmpty)) {
                        return 'Questo campo non può essere vuoto';
                      }
                      return null;
                    },
                  ),
                );
              }).toList(),
              if (!_isNewRecord && widget.initialData!['id'] == 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _verificaEApriCatalogo,
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Verifica e Apri Catalogo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveData,
        label: const Text('SALVA'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}
