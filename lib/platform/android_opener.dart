import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import 'opener_platform_interface.dart';

// Funzione top-level che verrà eseguita in un Isolate separato.
Future<String> _copyFileToPublicDirectory(Map<String, String> paths) async {
  final sourcePath = paths['source']!;
  final destinationFileName = paths['destination']!;

  final sourceFile = File(sourcePath);
  if (!await sourceFile.exists()) {
    throw Exception('File sorgente non trovato per la copia: $sourcePath');
  }

  final List<Directory>? downloadsDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
  if (downloadsDirs == null || downloadsDirs.isEmpty) {
    throw Exception('Impossibile accedere alla cartella Download.');
  }
  final Directory downloadsDir = downloadsDirs.first;
  
  final destinationPath = p.join(downloadsDir.path, destinationFileName);
  await sourceFile.copy(destinationPath);
  return destinationPath;
}


class AndroidOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    print("--- ANDROID OPENER (con copia) ---");
    print("Richiesto file: $filePath");

    try {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          throw Exception('Permesso di accesso allo storage negato.');
        }
      }

      if (context != null && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // FIX: Normalizza il percorso per rimuovere eventuali doppi slash.
      final sanitizedPath = filePath.replaceAll('//', '/');
      print("Percorso sanificato: $sanitizedPath");

      // La logica di copia viene mantenuta per la verifica manuale.
      final publicFilePath = await compute(_copyFileToPublicDirectory, {
        'source': sanitizedPath, 
        'destination': p.basename(sanitizedPath),
      });

      print("INFO: File copiato in una cartella pubblica: $publicFilePath");

      if (context != null && context.mounted) {
        Navigator.of(context).pop();
      }
      
      final result = await OpenFilex.open(publicFilePath);

      if (result.type != ResultType.done) {
        throw Exception('Impossibile aprire il file con lettore esterno: ${result.message}');
      }

    } catch (e) {
      if (context != null && context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ERRORE: $e'),
          backgroundColor: Colors.red,
        ));
      }
      print("### ERRORE APERTURA PDF ANDROID: $e");
    }
  }
}
