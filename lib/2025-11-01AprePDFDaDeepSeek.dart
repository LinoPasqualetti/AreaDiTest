import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';



class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final int? page; // Aggiunto parametro opzionale per la pagina

  const PdfViewerScreen({super.key, required this.pdfPath, this.page});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizza PDF'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text('Documento PDF', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              '${widget.pdfPath}${widget.page != null ? ' (Pagina: ${widget.page})' : ''}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _openPdfWithUrlLauncher,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Icon(Icons.open_in_browser),
              label: Text(_isLoading ? 'APERTURA...' : 'APRI FILE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdfWithUrlLauncher() async {
    setState(() => _isLoading = true);

    try {
      Uri uri = Uri.file(widget.pdfPath);
      if (widget.page != null) {
        uri = uri.replace(fragment: 'page=${widget.page}');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError("Impossibile lanciare l'URL: $uri"); // FIX: Usate doppie virgolette
      }
    } catch (e) {
      _showError('Errore durante l\'apertura: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
