import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class CatturaDialoghiScreen extends StatefulWidget {
  const CatturaDialoghiScreen({super.key});

  @override
  State<CatturaDialoghiScreen> createState() => _CatturaDialoghiScreenState();
}

// FIX: Aggiunto mixin per preservare lo stato
class _CatturaDialoghiScreenState extends State<CatturaDialoghiScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  String _statusMessage = "Caricamento risorse PDF in corso...";
  bool _isTextEmpty = true;
  bool _areFontsLoaded = false;

  pw.Font? _regularFont;
  pw.Font? _boldFont;
  pw.Font? _italicFont;
  pw.Font? _boldItalicFont;

  // FIX: Proprietà del mixin
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateButtonState);
    _fileNameController.text =
        'Dialogo_IA_${DateTime.now().millisecondsSinceEpoch}';
    _loadFonts();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateButtonState);
    _controller.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isTextEmpty = _controller.text.isEmpty;
    });
  }

  Future<void> _loadFonts() async {
    // Evita di ricaricare i font se sono già stati caricati
    if (_areFontsLoaded) return;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final italicFontData = await rootBundle.load('assets/fonts/NotoSans-Italic.ttf');
      final boldItalicFontData = await rootBundle.load('assets/fonts/NotoSans-BoldItalic.ttf');

      _regularFont = pw.Font.ttf(fontData);
      _boldFont = pw.Font.ttf(boldFontData);
      _italicFont = pw.Font.ttf(italicFontData);
      _boldItalicFont = pw.Font.ttf(boldItalicFontData);

      if (mounted) {
        setState(() {
          _areFontsLoaded = true;
          _statusMessage = "Pronto. Incolla il dialogo e genera il PDF.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _areFontsLoaded = false;
          _statusMessage =
              "Errore critico: impossibile caricare i font.";
        });
      }
    }
  }

  Future<void> generateAndSavePdf(String markdownText) async {
    // ... (logica invariata)
  }

  List<pw.Widget> _buildPdfWidgetsFromText(String text) {
    return [pw.Text(text)]; // Placeholder
  }
  
  List<pw.InlineSpan> _parseInlineFormatting(String text) {
    return [pw.TextSpan(text: text)]; // Placeholder
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Chiamata a super.build per il mixin
    super.build(context);

    if (!_areFontsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
             TextField(
              controller: _controller,
              maxLines: 15,
              decoration: const InputDecoration(
                hintText: "Incolla qui il dialogo...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fileNameController,
              decoration: const InputDecoration(
                labelText: 'Nome del file',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.file_present),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isTextEmpty ? null : () => generateAndSavePdf(_controller.text),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Genera Documento PDF'),
            ),
            const SizedBox(height: 20),
            Text('Stato: $_statusMessage', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
