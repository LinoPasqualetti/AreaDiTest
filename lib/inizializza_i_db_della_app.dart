import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'main.dart'; // Per le variabili globali
import 'database_utils.dart';

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';
const String _primoVuotoName = 'PrimoVuoto.db';

/// Funzione "Guardiano" con logica di creazione e correzione "platform-aware".
Future<void> inizializzaIDbDellaApp() async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    print("--- GUARDIANO: Inizio inizializzazione in: ${supportDir.path} ---");

    final vecchioDbPath = p.join(supportDir.path, _vecchioDbName);
    if (!await databaseExists(vecchioDbPath)) {
      print("INFO: VecchioDb.db non trovato. Avvio procedura di creazione e popolamento mirato...");
      
      final ByteData data = await rootBundle.load(p.join('assets', 'databases', _vecchioDbName));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "asset_seed.db");
      await File(tempAssetDbPath).writeAsBytes(bytes, flush: true);
      Database seedDb = await openReadOnlyDatabase(tempAssetDbPath);

      Database newDb = await openDatabase(vecchioDbPath);

      try {
        final sourceTableName = Platform.isWindows ? 'spartiti' : 'spartiti_andr';
        final dataToInsert = await seedDb.query(sourceTableName);

        await newDb.transaction((txn) async {
          final batch = txn.batch();
          batch.execute('CREATE TABLE $gSpartitiTableName (id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT, IdBra INTEGER UNIQUE, titolo TEXT, autore TEXT, strumento TEXT, volume TEXT, PercRadice TEXT, PercResto TEXT, PrimoLInk TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT, IdAutore TEXT)');
          for (final row in dataToInsert) {
            batch.insert(gSpartitiTableName, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          await batch.commit(noResult: true);
        });

      } finally {
        await seedDb.close();
        await newDb.close();
        await deleteDatabase(tempAssetDbPath);
      }
    }

    Database dbToValidate = await openDatabase(vecchioDbPath);
    try {
      final ftsTableExistsResult = await dbToValidate.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'");
      if (ftsTableExistsResult.isEmpty) {
        print("WARN: Tabella FTS non trovata! La creo e la popolo ora (Upgrade).");
        await dbToValidate.execute('CREATE VIRTUAL TABLE spartiti_fts USING fts5(titolo, autore, strumento, content="$gSpartitiTableName", content_rowid="IdBra")');
        await dbToValidate.execute('INSERT INTO spartiti_fts(spartiti_fts) VALUES(\'rebuild\')');
        print("INFO: Upgrade FTS completato.");
      }
    } finally {
      await dbToValidate.close();
    }

    await initDatabase(_dbGlobaleName);
    final primoVuotoPath = p.join(supportDir.path, _primoVuotoName);
    if (!await databaseExists(primoVuotoPath)) {
      const createStatement = 'CREATE TABLE $gSpartitiTableName ( id_univoco_globale INTEGER UNIQUE, IdBra TEXT,titolo TEXT, autore TEXT,strumento TEXT, volume TEXT,PercRadice TEXT, PercResto TEXT, PrimoLInk  TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT,IdAutore TEXT, PRIMARY KEY (id_univoco_globale AUTOINCREMENT))';
      Database dbVuoto = await openDatabase(primoVuotoPath, version: 1, onCreate: (db, version) => db.execute(createStatement));
      await dbVuoto.close();
    }
    
    gDbGlobale = await openDatabase(p.join(supportDir.path, _dbGlobaleName));
    gDbGlobalePath = gDbGlobale!.path;

    // --- FIX: Logica di correzione "Platform-Aware" ---
    String os = Platform.operatingSystem;
    String tipoInterfaccia = kIsWeb ? 'Web' : 'Nativa';
    String percorsoPdfDefault = Platform.isAndroid ? "/storage/emulated/0/JamsetPDF/" : "C:\\JamsetPDF\\";
    String percorsodatabaseDefault = supportDir.path;

    var datiSistemaResult = await gDbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistemaResult.isEmpty) {
      print("INFO: DatiSistremaApp è vuota. Inserisco il record di default per $os");
      await gDbGlobale!.insert('DatiSistremaApp', {
        'SistemaOperativo': os,
        'TipoInterfaccia': tipoInterfaccia,
        'PercorsoPdf': percorsoPdfDefault,
        'Percorsodatabase': percorsodatabaseDefault,
        'id_catalogo_attivo': 1
      });
    } else {
      final currentRecord = datiSistemaResult.first;
      Map<String, Object?> idealRecord = {
        'SistemaOperativo': os,
        'TipoInterfaccia': tipoInterfaccia,
        'PercorsoPdf': percorsoPdfDefault,
        'Percorsodatabase': percorsodatabaseDefault,
      };

      bool needsUpdate = idealRecord.keys.any((key) => currentRecord[key] != idealRecord[key]);
      
      if (needsUpdate) {
        print("WARN: DatiSistremaApp contiene valori non corretti per $os. Eseguo UPDATE.");
        // FIX: Rimuove la clausola WHERE, dato che DatiSistremaApp è una tabella singleton
        await gDbGlobale!.update('DatiSistremaApp', idealRecord);
      }
    }

    datiSistemaResult = await gDbGlobale!.query('DatiSistremaApp', limit: 1);
    var currentConfig = datiSistemaResult.first;
    int? idCatalogoAttivo = currentConfig['id_catalogo_attivo'] as int?;

    final catalogoEsiste = await gDbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo]);
    if (catalogoEsiste.isEmpty) {
        idCatalogoAttivo = 1;
    }
    
    final catalogoInfoResult = await gDbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo], limit: 1);
    if (catalogoInfoResult.isEmpty) throw Exception('ERRORE FATALE: Catalogo default con ID $idCatalogoAttivo non trovato.');
    
    final catalogoInfo = catalogoInfoResult.first;
    gActiveCatalogDbName = catalogoInfo['nome_file_db'] as String;
    gPercorsoPdf = (currentConfig['PercorsoPdf'] as String?) ?? '';
    
    gDatabase = await openDatabase(p.join(supportDir.path, gActiveCatalogDbName));
    gVecchioDbPath = gDatabase!.path;

    print("***** INIZIALIZZAZIONE GLOBALE COMPLETATA *****");

  } catch (e, s) {
    print("### ERRORE INIZIALIZZAZIONE (Guardiano): $e ###");
    print("### STACK TRACE: $s ###");
    gDbGlobale = null;
    gDatabase = null;
    rethrow;
  }
}
