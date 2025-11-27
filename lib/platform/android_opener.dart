import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart'; // Per il navigatorKey
import 'opener_platform_interface.dart';
import '../pdf_viewer_screen.dart'; // La nostra nuova schermata

class AndroidOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    print("--- ANDROID OPENER (con viewer interno) ---");
    print("Richiesto file: $filePath a pagina $page");

    try {
      // FIX: Richiede il permesso corretto, MANAGE_EXTERNAL_STORAGE, che corrisponde
      // a quello dichiarato in AndroidManifest.xml per la massima compatibilità.
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        print("Permesso MANAGE_EXTERNAL_STORAGE non concesso. Lo richiedo...");
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          throw Exception('Permesso di accesso a tutti i file negato dall\'utente.');
        }
      }

      final sanitizedPath = filePath.replaceAll('//', '/');
      print("Percorso sanificato: $sanitizedPath");

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            filePath: sanitizedPath,
            initialPage: page > 0 ? page - 1 : 0,
          ),
        ),
      );

    } catch (e) {
      final errorMessage = e.toString();
      print("### ERRORE APERTURA PDF ANDROID: $errorMessage");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ERRORE: $errorMessage'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}
