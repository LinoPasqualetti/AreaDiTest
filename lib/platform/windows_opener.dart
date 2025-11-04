import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart'; // Corretto con percorso relativo
import 'opener_platform_interface.dart'; // Corretto con percorso relativo
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart'; 

class WindowsOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    final fileExtension = p.extension(filePath).toLowerCase();

    try {
      if (fileExtension == '.pdf') {
        final pdfViewerPath = gPercorsoPdf; // Usa la variabile globale da main.dart
        if (pdfViewerPath.isEmpty) {
          if(context != null) _showErrorDialog(context, 'Errore di Configurazione', 'Il percorso del lettore PDF non è stato impostato.');
          return;
        }

        final args = ['/A', 'page=$page', filePath];
        await Process.start(pdfViewerPath, args, runInShell: false);

      } else {
        final Uri fileUri = Uri.file(filePath);
        
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          throw Exception('Impossibile lanciare l\'URL per il file: $filePath');
        }
      }
    } catch (e) {
      if (context != null) {
        _showErrorDialog(
          context,
          'Eccezione Apertura File',
          '''Si è verificato un errore imprevisto durante l'apertura del file.\n\nDettagli: $e''',
        );
      }
    }
  }

  Future<void> _showErrorDialog(BuildContext context, String title, String content) {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
}
