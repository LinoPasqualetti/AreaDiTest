import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:area_di_test/main.dart'; // Import per accedere a gDbGlobale

class TestAperturaFilesScreen extends StatefulWidget {
  const TestAperturaFilesScreen({super.key});

  @override
  State<TestAperturaFilesScreen> createState() => _TestAperturaFilesScreenState();
}

class _TestAperturaFilesScreenState extends State<TestAperturaFilesScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _basePathController = TextEditingController();
  final TextEditingController _percRestoController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();

  String _statusMessage = 'Pronto per il test.';
  String _constructedPath = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBasePathFromDb(); // Carica il percorso base dal DB all'avvio
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pageController.dispose();
    _basePathController.dispose();
    _percRestoController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  /// Legge il percorso base dal DB all'avvio della schermata.
  Future<void> _loadBasePathFromDb() async {
    if (gDbGlobale != null && gDbGlobale!.isOpen) {
      try {
        final List<Map<String, dynamic>> datiSistema = await gDbGlobale!.query('DatiSistremaApp', limit: 1);
        if (datiSistema.isNotEmpty && datiSistema.first['PercorsoPdf'] != null) {
          final percorsoPdf = datiSistema.first['PercorsoPdf'] as String;
          if (mounted) {
            setState(() {
              _basePathController.text = percorsoPdf;
            });
          }
        }
      } catch (e) {
        _updateError("Impossibile caricare PercorsoPdf dal DB: $e");
      }
    }
  }

  void _updateStatus(String message) {
    if (mounted) setState(() => _statusMessage = message);
  }

  void _updateError(dynamic e) {
    if (mounted) setState(() => _statusMessage = 'ERRORE: ${e.toString()}');
  }

  /// Costruisce il percorso finale tramite semplice concatenazione.
  void _showComposedPath() {
    final basePath = _basePathController.text;
    final percResto = _percRestoController.text;
    final volume = _volumeController.text;
    if (basePath.isEmpty || percResto.isEmpty) {
      _updateStatus('Errore: I campi per la costruzione del percorso sono vuoti.');
      return;
    }
    // Semplice concatenazione come richiesto
    final filePath = '$basePath$percResto$volume';
    setState(() {
      _constructedPath = filePath;
    });
    _updateStatus('Percorso costruito. Ora puoi testare l\'esistenza o l\'apertura.');
  }

  /// Controlla se il file esiste al percorso dell'Input Principale.
  Future<void> _checkFileExistence() async {
    final pathToCheck = _pathController.text.trim();
    if (pathToCheck.isEmpty) {
      _updateStatus('Errore: Il percorso nell\'Input Principale è vuoto.');
      return;
    }
    try {
      final file = File(pathToCheck);
      final exists = await file.exists();
      if (exists) {
        _updateStatus('OK: Il file esiste al percorso principale specificato.');
      } else {
        _updateStatus('ERRORE: Il file NON è stato trovato al percorso principale specificato.');
      }
    } catch (e) {
      _updateError(e);
    }
  }

  /// Estrae i valori dal percorso completo.
  void _deduceAndConstructPath() {
    String deducedPercResto = '';
    String deducedVolume = '';
    final fullPath = _pathController.text.trim();

    if (fullPath.isNotEmpty) {
      const marker = 'JamsetPDF'; // Assumendo che questo sia il marcatore
      final markerIndex = fullPath.toLowerCase().indexOf(marker.toLowerCase());

      final lastSlash = fullPath.lastIndexOf('/');
      final lastBackslash = fullPath.lastIndexOf(r'\');
      final lastSeparatorIndex = max(lastSlash, lastBackslash);

      if (lastSeparatorIndex != -1) {
        deducedVolume = fullPath.substring(lastSeparatorIndex + 1);
        if (markerIndex != -1) {
          final percRestoStartIndex = markerIndex + marker.length + (fullPath.length > markerIndex + marker.length && (fullPath[markerIndex + marker.length] == '/' || fullPath[markerIndex + marker.length] == r'\') ? 1 : 0);
          if (percRestoStartIndex <= lastSeparatorIndex) {
            deducedPercResto = fullPath.substring(percRestoStartIndex, lastSeparatorIndex + 1);
          }
        }
      }

      setState(() {
        _percRestoController.text = deducedPercResto;
        _volumeController.text = deducedVolume;
      });
      _updateStatus('Valori estratti. Ora puoi costruire il percorso.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGenericTestSection(),
            const Divider(thickness: 2),
            _buildDeductionTestSection(),
            const Divider(thickness: 2),
            _buildAndroidTestSection(),
            const Divider(thickness: 2),
            _buildOpenTestSection(),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Risultato Operazione:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(_statusMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. Input Principale (per estrazione)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(
          maxLines: 1,
          controller: _pathController,
          decoration: const InputDecoration(labelText: 'Incolla qui il percorso completo (es. da Windows)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(controller: _pageController, decoration: const InputDecoration(labelText: 'NumPag (opzionale)', border: OutlineInputBorder()), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      ],
    );
  }

  Widget _buildDeductionTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('2. Estrai Valori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton.icon(onPressed: _deduceAndConstructPath, icon: const Icon(Icons.science), label: const Text('Estrai')),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _percRestoController, decoration: const InputDecoration(labelText: 'PercResto', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _volumeController, decoration: const InputDecoration(labelText: 'Volume', border: OutlineInputBorder()))),
          ],
        ),
      ],
    );
  }

  Widget _buildAndroidTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('3. Costruisci e Verifica', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(controller: _basePathController, decoration: const InputDecoration(labelText: 'Percorso Base (da DB)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(onPressed: _showComposedPath, icon: const Icon(Icons.construction), label: const Text('Costruisci')),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _checkFileExistence,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Verifica Esistenza'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100]),
            )
          ],
        ),
        const SizedBox(height: 8),
        const Text('Percorso Costruito:', style: TextStyle(fontWeight: FontWeight.bold)),
        SelectableText(_constructedPath, style: const TextStyle(color: Colors.deepPurple, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildOpenTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('4. Testa Apertura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            ElevatedButton.icon(
              onPressed: () { _updateStatus("Pulsante 'Apertura Diretta' premuto. Logica non implementata."); },
              icon: const Icon(Icons.file_open),
              label: const Text('1. Apertura Diretta'),
            ),
            ElevatedButton.icon(
              onPressed: () { _updateStatus("Pulsante 'Reader Esterno' premuto. Logica non implementata."); },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('2. Reader Esterno'),
            ),
            ElevatedButton.icon(
              onPressed: () { _updateStatus("Pulsante 'Gestore Interno' premuto. Logica non implementata."); },
              icon: const Icon(Icons.integration_instructions_outlined),
              label: const Text('3. Gestore Interno (Jamset)'),
            ),
            ElevatedButton.icon(
              onPressed: () { _updateStatus("Pulsante 'Browser (URI)' premuto. Logica non implementata."); },
              icon: const Icon(Icons.public),
              label: const Text('4. Browser (URI)'),
            ),
          ],
        )
      ],
    );
  }
}