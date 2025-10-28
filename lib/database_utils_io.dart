import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Inizializza il database per piattaforme che supportano 'dart:io' (Desktop, Mobile).
Future<Database> initDatabase(String dbName) async {
  final supportDir = await getApplicationSupportDirectory();
  final path = p.join(supportDir.path, dbName);

  // Copia il DB dagli asset solo se non esiste già.
  if (!await databaseExists(path)) {
    try {
      await Directory(p.dirname(path)).create(recursive: true);
      ByteData data = await rootBundle.load('assets/databases/$dbName');
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw Exception("Errore durante la copia del database: $e");
    }
  }

  return openDatabase(path);
}
