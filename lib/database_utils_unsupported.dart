
import 'package:sqflite/sqflite.dart';

// Implementazione di fallback per piattaforme non supportate.
Future<Database> initDatabase(String dbName) =>
    throw UnimplementedError('Piattaforma non supportata per l'inizializzazione del database.');
