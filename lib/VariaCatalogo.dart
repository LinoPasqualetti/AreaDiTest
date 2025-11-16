///////////// VariaCatalogo.dart Emette lo schermo per Inserire e variare un catalogo//////////////////////
///////// generalmente chiamato da GestisciElencoCataloghi.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';

import 'main.dart'; // Import per usare gDbGlobale
import 'database_utils.dart';
import 'lista_spartiti_catalogo.dart';

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

  // FIX: La logica ora usa la connessione globale gDbGlobale
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate() || gDbGlobale == null) return;

    print('--- Inizio operazione DB: _saveData ---');
    try {
      final db = gDbGlobale!; // Usa la connessione esistente
      print('[OK] Uso la connessione gDbGlobale');
      
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

      // NON CHIUDERE PIU' LA CONNESSIONE!
      // await db.close(); 

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

  // FIX: La logica ora usa la connessione globale gDbGlobale
  Future<void> _deleteData() async {
    if (_isNewRecord || widget.initialData == null || gDbGlobale == null) return;

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
        final db = gDbGlobale!; // Usa la connessione esistente
        print('[OK] Uso la connessione gDbGlobale');
        print('Eseguo DELETE su elenco_cataloghi (ID: $id)...');
        await db.delete('elenco_cataloghi', where: 'id = ?', whereArgs: [id]);
        print('[OK] Operazione completata');

        // NON CHIUDERE PIU' LA CONNESSIONE!
        // await db.close();

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
    // ... (questa funzione non tocca il DB, non serve modificarla)
  }

  Future<void> _verificaEApriCatalogo() async {
    // ... (questa funzione non tocca il DB, non serve modificarla)
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
