import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Inizializza il database per la piattaforma WEB.
Future<Database> initDatabase(String dbName) async {
  final factory = databaseFactory as DatabaseFactoryFfiWeb;

  // Sul web, il DB viene sempre copiato dagli asset in IndexedDB.
  // Le modifiche andranno perse ad ogni ricaricamento completo della pagina.
  try {
    final data = await rootBundle.load('assets/databases/$dbName');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await factory.writeDatabaseBytes(dbName, bytes);
  } catch (e) {
    throw Exception("Errore durante la copia del database per il web: $e");
  }

  return factory.openDatabase(dbName);
}
