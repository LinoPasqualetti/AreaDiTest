import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jamset/platform/opener_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

// Enum per definire la modalità di apertura desiderata
enum PdfOpenMode { NATIVO, NEL_BROWSER }

class PdfOpenerUtils {
  // Percorsi hardcoded per i browser su desktop. Possono essere resi configurabili.
  static const _windowsChromePath = r'C:\Program Files\Google\Chrome\Application\chrome.exe';
  static const _macOsChromePath = r'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

  /// Verifica l'esistenza di un file PDF e restituisce il suo percorso completo.
  /// Questa funzione è flessibile e riceve la base del percorso dall'esterno.
  static Future<String?> verificaPercorsoPdf({
    required String basePath, // Può essere un path locale (C:\...) o un URL base (http://...)
    required String subPath,
    required String fileName,
  }) async {
    String percorsoFinaleDaAprire;
    bool risorsaEsiste = false;

    try {
      if (kIsWeb) {
        // Se siamo sul web, basePath è l'URL del server.
        String percorsoRelativo = '$subPath$fileName'.replaceAll(r'\', '/');
        if (percorsoRelativo.startsWith('/')) {
          percorsoRelativo = percorsoRelativo.substring(1);
        }
        percorsoFinaleDaAprire = "$basePath/${Uri.encodeFull(percorsoRelativo)}";
        final response = await http.head(Uri.parse(percorsoFinaleDaAprire));
        risorsaEsiste = (response.statusCode == 200);
      } else {
        // Se non siamo sul web, basePath è una radice del file system.
        percorsoFinaleDaAprire = '$basePath\\$subPath$fileName'; // Semplificazione
        risorsaEsiste = await io.File(percorsoFinaleDaAprire).exists();
      }
    } catch (e) {
      debugPrint("Errore durante la verifica del percorso: $e");
      return null;
    }

    return risorsaEsiste ? percorsoFinaleDaAprire : null;
  }

  /// Apre un file PDF in base alla piattaforma e alla modalità richiesta.
  static Future<void> apriPdf({
    required BuildContext context,
    required String percorsoPdf,
    required PdfOpenMode mode,
    int? page,
  }) async {
    if (mode == PdfOpenMode.NEL_BROWSER) {
      await _apriNelBrowser(context, percorsoPdf, page: page);
    } else {
      await _apriNativo(context, percorsoPdf, page: page);
    }
  }

  // -- METODI PRIVATI DI SUPPORTO --

  static Future<void> _apriNelBrowser(BuildContext context, String percorso, {int? page}) async {
    if (kIsWeb) {
      String urlConPagina = percorso;
      if (page != null && page > 0) {
        urlConPagina = '$urlConPagina#page=$page';
      }
      final uri = Uri.parse(urlConPagina);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossibile aprire l'URL: $uri")));
      }
    } else if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
      await _openFileInBrowserOnDesktop(context, percorso, page: page);
    } else {
      // Su MOBILE
      final uri = Uri.file(percorso); // <-- CORREZIONE: rimosso il prefisso "io."
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossibile trovare un'app per aprire il file: $uri")));
      }
    }
  }

  static Future<void> _apriNativo(BuildContext context, String percorso, {int? page}) async {
    await OpenerPlatformInterface.instance.openPdf(
      context: context,
      filePath: percorso,
      page: page ?? 1,
    );
  }

  static Future<void> _openFileInBrowserOnDesktop(BuildContext context, String filePath, {int? page}) async {
    String? browserPath;
    List<String> arguments = [filePath];

    if (io.Platform.isWindows) {
      browserPath = _windowsChromePath;
    } else if (io.Platform.isMacOS) {
      await io.Process.run('open', ['-a', 'Google Chrome', filePath]);
      return;
    } else if (io.Platform.isLinux) {
      browserPath = 'google-chrome';
    }

    if (browserPath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Piattaforma non supportata per questa funzione.")));
      }
      return;
    }

    try {
      final result = await io.Process.run(browserPath, arguments);
      if (result.exitCode != 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore del browser: ${result.stderr}")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossibile avviare il browser: $e")));
      }
    }
  }
}
