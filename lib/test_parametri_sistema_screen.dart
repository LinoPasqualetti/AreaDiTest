import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TestParametriSistemaScreen extends StatefulWidget {
  const TestParametriSistemaScreen({super.key});

  @override
  State<TestParametriSistemaScreen> createState() =>
      _TestParametriSistemaScreenState();
}

// FIX: Aggiunto mixin per preservare lo stato
class _TestParametriSistemaScreenState extends State<TestParametriSistemaScreen> with AutomaticKeepAliveClientMixin {
  Map<String, String> _pathData = {};
  bool _isLoading = true;

  // FIX: Proprietà del mixin
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    if (!mounted) return;
    // Non serve reimpostare _isLoading a true se i dati ci sono già
    if (_pathData.isNotEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, String> paths = {};

      if (kIsWeb) {
        paths = {
          'Piattaforma': 'Web',
          'Accesso File System': 'Non disponibile (usa IndexedDB)',
        };
      } else {
        final supportDir = await getApplicationSupportDirectory();
        paths = {
          'Cartella Dati App (Locale)': supportDir.path,
          'Percorso Asset (relativo)': 'assets/',
        };
      }

      if (mounted) {
        setState(() {
          _pathData = paths;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pathData = {'Errore': 'Impossibile ottenere i percorsi: ${e.toString()}'};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Chiamata a super.build per il mixin
    super.build(context);
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPaths,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSection('Percorsi Principali Applicazione', _pathData),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Map<String, String> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 8),
        if (data.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Nessun dato disponibile.'),
          )
        else
          ...data.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SelectableText(entry.value),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
