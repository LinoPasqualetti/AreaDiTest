import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MainTestaFiles extends StatefulWidget {
  const MainTestaFiles({super.key});

  @override
  State<MainTestaFiles> createState() => _MainTestaFilesState();
}

class _MainTestaFilesState extends State<MainTestaFiles> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  String _statusMessage = 'Pronto per il test di apertura.';

  @override
  void dispose() {
    _pathController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _updateStatus(String message) {
    setState(() => _statusMessage = message);
  }

  void _updateError(dynamic e) {
    setState(() => _statusMessage = 'ERRORE: ${e.toString()}');
  }

  // --- LOGICHE DI APERTURA ---

  void _openDirectly() => _updateStatus("Pulsante 'Apertura Diretta' premuto. Logica non implementata.");
  void _openWithExternalReader() => _updateStatus("Pulsante 'Reader Esterno' premuto. Logica non implementata.");
  void _openWithInternalManager() => _updateStatus("Pulsante 'Gestore Interno' premuto. Logica non implementata.");

  /// 4. Tenta di aprire il percorso come URI in un'app esterna (browser).
  Future<void> _openWithBrowser() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      _updateStatus('Errore: Il percorso del file non può essere vuoto.');
      return;
    }

    try {
      final page = _pageController.text.trim();
      Uri uri = Uri.file(path);

      if (page.isNotEmpty) {
        uri = uri.replace(fragment: 'page=$page');
      }

      _updateStatus('Tentativo di apertura come URI...\n$uri');

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw "Impossibile lanciare l'URL: $uri";
      }

      _updateStatus('Richiesta di apertura inviata al sistema.');
    } catch (e) {
      _updateError(e);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Apertura File (Isolato)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Percorso del file',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pageController,
              decoration: const InputDecoration(
                labelText: 'Numero di pagina (opzionale)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text('Modalità di Apertura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton.icon(
                  onPressed: _openDirectly,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('1. Apertura Diretta'),
                ),
                ElevatedButton.icon(
                  onPressed: _openWithExternalReader,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('2. Reader Esterno'),
                ),
                ElevatedButton.icon(
                  onPressed: _openWithInternalManager,
                  icon: const Icon(Icons.integration_instructions_outlined),
                  label: const Text('3. Gestore Interno'),
                ),
                ElevatedButton.icon(
                  onPressed: _openWithBrowser,
                  icon: const Icon(Icons.public),
                  label: const Text('4. Browser (URI)'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text('Stato:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(_statusMessage),
          ],
        ),
      ),
    );
  }
}
