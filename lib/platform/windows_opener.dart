import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import 'opener_platform_interface.dart';

class WindowsOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    final fileExtension = p.extension(filePath).toLowerCase();

    print("--- DEBUG APERTURA FILE ---");
    print("File: $filePath");
    print("Estensione: $fileExtension");
    print("---------------------------");

    try {
      if (fileExtension == '.pdf') {
        const viewerPath = r'C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe';
        const defaultViewerPath = r'C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe';

        String pdfViewerPath;
        if (await File(viewerPath).exists()) {
          pdfViewerPath = viewerPath;
        } else if (await File(defaultViewerPath).exists()) {
          pdfViewerPath = defaultViewerPath;
        } else {
          throw Exception('Nessun lettore PDF (Acrobat) trovato nei percorsi standard.');
        }

        // --- FIX DEFINITIVO: Ricostruisce gli argomenti nel formato corretto, come in Jamset. ---
        final args = ['/A', 'page=$page', filePath];
        // --- PRINT DI DEBUG AGGIUNTA ---
        print("--- COMANDO ACROBAT --- ");
        print("Eseguibile: $pdfViewerPath");
        print("Argomenti: ${args.join(' ')}");
        print("-----------------------");
        // --------------------------
        print("INFO: Eseguo comando: $pdfViewerPath con argomenti: $args");
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
