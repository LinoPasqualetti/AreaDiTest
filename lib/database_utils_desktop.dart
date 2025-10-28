
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Inizializzazione del database per piattaforme DESKTOP (e mobile).
Future<Database> initDatabase(String dbName) async {
  print("DESKTOP/MOBILE: Inizializzazione database '$dbName'.");

  // Usa il percorso di supporto dell'applicazione, che è sempre scrivibile.
  final appDir = await getApplicationSupportDirectory();
  final path = p.join(appDir.path, dbName);

  if (!await databaseExists(path)) {
    print("Database non trovato, copia da assets: $path");
    try {
      // Assicurati che la directory esista
      await Directory(p.dirname(path)).create(recursive: true);

      // Carica e scrivi il file del DB
      ByteData data = await rootBundle.load('assets/databases/$dbName');
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      print("Copia completata.");
    } catch (e) {
      throw Exception("Errore durante la copia del database: $e");
    }
  } else {
    print("Database già esistente in: $path");
  }

  // Apri il database dal percorso corretto
  return openDatabase(path);
}
