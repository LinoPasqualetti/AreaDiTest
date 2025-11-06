import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';

import 'database_utils.dart';
import 'GestisciElencoCataloghi.dart'; // Importa la nuova schermata

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _tabellaDatiSistema = 'DatiSistremaApp';

class AttivaDatieDB extends StatefulWidget {
  const AttivaDatieDB({super.key});

  @override
  State<AttivaDatieDB> createState() => _AttivaDatieDBState();
}

class _AttivaDatieDBState extends State<AttivaDatieDB> {
  final Map<String, TextEditingController> _controllers = {};
  List<Map<String, dynamic>> _cataloghiDisponibili = [];
  bool _isLoading = true;
  String _statusMessage = 'Caricamento dei dati di sistema...';

  @override
  void initState() {
    super.initState();
    _loadOrCreateAndLoadData();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrCreateAndLoadData() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final dbPath = p.join(supportDir.path, _dbGlobaleName);

      if (!await databaseExists(dbPath)) {
        _updateStatus('Database non trovato. Copia dagli asset in corso...');
        await initDatabase(_dbGlobaleName);
        _updateStatus('Copia completata. Caricamento dati...');
      }

      Database db = await openDatabase(dbPath);
      final List<Map<String, dynamic>> data = await db.query(_tabellaDatiSistema, limit: 1);
      _cataloghiDisponibili = await db.query('elenco_cataloghi');
      await db.close();

      if (data.isNotEmpty) {
        final systemData = Map<String, dynamic>.from(data.first);

        systemData['SistemaOperativo'] = Platform.operatingSystem;
        systemData['TipoInterfaccia'] = kIsWeb ? 'Web' : 'Nativa';
        systemData['Percorsodatabase'] = supportDir.path;

        _controllers.clear();
        for (var entry in systemData.entries) {
          _controllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
        }

        _updateStatus('Dati caricati. Modifica i valori e salva.');
      } else {
        _updateStatus('ERRORE: La tabella $_tabellaDatiSistema è vuota o non esiste.');
      }
    } catch (e) {
      _updateStatus('ERRORE CRITICO: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Salvataggio delle modifiche in corso...';
    });

    try {
      final supportDir = await getApplicationSupportDirectory();
      final dbPath = p.join(supportDir.path, _dbGlobaleName);
      Database db = await openDatabase(dbPath);

      Map<String, Object?> newData = {};
      for (var entry in _controllers.entries) {
        newData[entry.key] = entry.value.text;
      }

      await db.update(_tabellaDatiSistema, newData);
      await db.close();

      _updateStatus('Modifiche salvate! Apertura gestione cataloghi...');

      // Naviga alla schermata di gestione cataloghi
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const GestisciElencoCataloghi()),
        );
      }

    } catch (e) {
      _updateStatus('ERRORE DURANTE IL SALVATAGGIO: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }

  Future<void> _pickFolder(String controllerKey) async {
    if (kIsWeb) {
      _updateStatus('La selezione di cartelle non è supportata sul web.');
      return;
    }
    try {
      String? directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath != null) {
        setState(() {
          _controllers[controllerKey]?.text = directoryPath;
          _updateStatus('Percorso aggiornato per $controllerKey.');
        });
      } else {
        _updateStatus('Selezione cartella annullata.');
      }
    } catch (e) {
      _updateStatus('Errore durante la selezione della cartella: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trattamento dei Dati di Sistema'),
            Text(
              'tabella datiSistremaApp',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading && _controllers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: _controllers.entries.map((entry) {
              final fieldName = entry.key;
              final controller = entry.value;

              if (['SistemaOperativo', 'TipoInterfaccia', 'Percorsodatabase'].contains(fieldName)) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: controller,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: fieldName,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[200],
                      helperText: _getHelperText(fieldName),
                    ),
                  ),
                );
              }

              if (fieldName == 'PercorsoPdf') {
                 return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: fieldName,
                      border: const OutlineInputBorder(),
                      helperText: _getHelperText(fieldName),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () => _pickFolder(fieldName),
                        tooltip: 'Seleziona cartella',
                      ),
                    ),
                  ),
                );
              }

              if (fieldName == 'id_catalogo_attivo') {
                 return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    value: controller.text.isNotEmpty ? controller.text : null,
                    items: _cataloghiDisponibili.map((catalogo) {
                      return DropdownMenuItem<String>(
                        value: catalogo['id'].toString(),
                        child: Text(catalogo['NomeCatalogo']?.toString() ?? 'ID: ${catalogo['id']}'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => controller.text = newValue);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: fieldName,
                      border: const OutlineInputBorder(),
                      helperText: _getHelperText(fieldName),
                    ),
                  ),
                );
              }

              if (fieldName == 'ModoFiles') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField<String>(
                    value: controller.text.isNotEmpty ? controller.text : null,
                    items: ['dataSQL', 'CSV'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => controller.text = newValue);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: fieldName,
                      border: const OutlineInputBorder(),
                      helperText: _getHelperText(fieldName),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: fieldName,
                    border: const OutlineInputBorder(),
                    helperText: _getHelperText(fieldName),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveData,
                icon: const Icon(Icons.save),
                label: const Text('SALVA MODIFICHE'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (Navigator.canPop(context))
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('ESCI SENZA SALVARE'),
                ),
              const SizedBox(height: 8),
              SelectableText(_statusMessage, textAlign: TextAlign.center, style: _isLoading ? const TextStyle(color: Colors.blue) : null),
            ],
          ),
        )
      ],
    );
  }
  
  String? _getHelperText(String fieldName) {
    switch (fieldName) {
      case 'ModoFiles':
        return 'Valori ammessi: dataSQL, CSV';
      case 'PercorsoPdf':
        return 'Directory radice dei file PDF (es. C:\\JamsetPDF)';
      case 'Percorsodatabase':
        return 'Percorso dati interno dell\'applicazione (non modificabile)';
      case 'id_catalogo_attivo':
        return 'Seleziona il catalogo da usare all\'avvio';
      default:
        return null;
    }
  }
}
