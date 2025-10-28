import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class TestAperturaFilesScreen extends StatefulWidget {
  const TestAperturaFilesScreen({super.key});

  @override
  State<TestAperturaFilesScreen> createState() => _TestAperturaFilesScreenState();
}

class _TestAperturaFilesScreenState extends State<TestAperturaFilesScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _basePathController = TextEditingController(text: '/storage/emulated/0/JamsetPDF/');
  final TextEditingController _percRestoController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();

  String _statusMessage = 'Pronto per il test.';
  String _constructedPath = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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

  void _updateStatus(String message) {
    if (mounted) setState(() => _statusMessage = message);
  }

  void _updateError(dynamic e) {
    if (mounted) setState(() => _statusMessage = 'ERRORE: ${e.toString()}');
  }

  Future<void> _openPath({bool withPage = false}) async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      _updateStatus('Errore: Il percorso/URL non può essere vuoto.');
      return;
    }
    try {
      if (path.startsWith('http') || path.startsWith('https')) {
        final Uri uri;
        if (withPage && _pageController.text.isNotEmpty) {
          uri = Uri.parse(path).replace(fragment: 'page=${_pageController.text}');
        } else {
          uri = Uri.parse(path);
        }
        _updateStatus('Rilevato URL. Tentativo di apertura...\n$uri');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw "Impossibile lanciare l'URL: $uri";
        }
      } else {
        final pageFragment = (withPage && _pageController.text.isNotEmpty)
            ? '#page=${_pageController.text}'
            : '';
        final fullPath = '$path$pageFragment';
        _updateStatus('Rilevato percorso locale. Tentativo di apertura...\n$fullPath');
        final result = await OpenFilex.open(fullPath);
        _updateStatus('Codice: ${result.type}\nMessaggio: ${result.message}');
      }
    } catch (e) {
      _updateError(e);
    }
  }
  
  void _showComposedAndroidPath() {
    final basePath = _basePathController.text;
    final percResto = _percRestoController.text;
    final volume = _volumeController.text;
    if (basePath.isEmpty || percResto.isEmpty) {
      _updateStatus('Errore: I campi per la costruzione del percorso sono vuoti.');
      return;
    }
    final filePath = '$basePath$percResto$volume';
    final pageFragment = _pageController.text.isNotEmpty
        ? '#page=${_pageController.text}'
        : '';
    final fullPath = '$filePath$pageFragment';
    _updateStatus('Percorso generato (solo visualizzazione):\n$fullPath');
  }

  void _deduceAndConstructPath() {
    String resultPath = '';
    String deducedPercResto = '';
    String deducedVolume = '';
    final fullPath = _pathController.text.trim();

    if (fullPath.isNotEmpty) {
      const marker = 'JamsetPDF';
      final markerIndex = fullPath.indexOf(marker);
      
      final lastSlash = fullPath.lastIndexOf('/');
      final lastBackslash = fullPath.lastIndexOf(r'\');
      final lastSeparatorIndex = max(lastSlash, lastBackslash);

      if (lastSeparatorIndex != -1) {
        deducedVolume = fullPath.substring(lastSeparatorIndex + 1);

        if (markerIndex != -1) {
          final percRestoStartIndex = markerIndex + marker.length + 1;
          if (percRestoStartIndex <= lastSeparatorIndex) {
            deducedPercResto = fullPath.substring(percRestoStartIndex, lastSeparatorIndex + 1);
          }
        }
      }
      
      if (Platform.isAndroid) {
        final basePath = _basePathController.text.trim();
        if (markerIndex != -1) {
          final startIndex = markerIndex + marker.length + 1;
          if (startIndex < fullPath.length) {
            final subPath = fullPath.substring(startIndex).replaceAll(r'\', '/');
            resultPath = p.join(basePath, subPath);
          }
        }
      } else if (Platform.isWindows) {
          resultPath = fullPath;
      }
    }

    setState(() {
      _constructedPath = resultPath;
      _percRestoController.text = deducedPercResto;
      _volumeController.text = deducedVolume;
    });
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
            //const SizedBox(height: 24),
            const Divider(thickness: 2),
            _buildDeductionTestSection(),
            //const SizedBox(height: 24),
            const Divider(thickness: 2),
            _buildAndroidTestSection(),
           // const SizedBox(height: 24),
            const Divider(),
            //const SizedBox(height: 12),
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
        const Text('1. Input Principale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        //const SizedBox(height: 16),
        TextField(
          maxLines: 1,
          controller: _pathController, 
          decoration: const InputDecoration(
            labelText: 'Incolla qui il percorso completo', 
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          )
        ),
        const SizedBox(height: 16),
        TextField(controller: _pageController, decoration: const InputDecoration(labelText: 'NumPag (opzionale)', border: OutlineInputBorder()), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
      ],
    );
  }
  
  Widget _buildDeductionTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('2. Estrai Valori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _deduceAndConstructPath,
              icon: const Icon(Icons.science),
              label: const Text('Estrai'),
            ),
           // const SizedBox(width: 16),
            Expanded(
              child: TextField(controller: _percRestoController, decoration: const InputDecoration(labelText: 'PercResto', border: OutlineInputBorder())),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(controller: _volumeController, decoration: const InputDecoration(labelText: 'Volume', border: OutlineInputBorder())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAndroidTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('3. Costruisci e Testa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextField(controller: _basePathController, decoration: const InputDecoration(labelText: 'Percorso di Base Android', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: _showComposedAndroidPath, icon: const Icon(Icons.construction), label: const Text('Mostra')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text('Percorso Generato: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                    child: SelectableText(_constructedPath, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold))
                ),
            ],
        ),
      ],
    );
  }
}
