import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'main.dart'; // Per le variabili globali
import 'database_utils.dart';

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';
const String _primoVuotoName = 'PrimoVuoto.db';

/// Funzione "Guardiano" autonoma e riutilizzabile.
/// Ad ogni avvio, si assicura che i 3 database fondamentali esistano,
/// creandoli se necessario. Dopodiché, tenta di aprire e impostare il catalogo attivo.
Future<void> inizializzaIDbDellaApp() async {
  try {
    final supportDir = await getApplicationSupportDirectory();

    // Fase 1: Assicura l'esistenza dei 3 DB fondamentali.
    // initDatabase copia il file dall'asset solo se non esiste nella cartella di lavoro.
    await initDatabase(_dbGlobaleName);
    await initDatabase(_vecchioDbName);

    // Controlla e crea PrimoVuoto.db solo se non esiste.
    final primoVuotoPath = p.join(supportDir.path, _primoVuotoName);
    if (!await databaseExists(primoVuotoPath)) {
      print("INFO: Creazione di $_primoVuotoName non trovato...");
      const createStatement = 'CREATE TABLE $gSpartitiTableName ( id_univoco_globale INTEGER UNIQUE, IdBra TEXT,titolo TEXT, autore TEXT,strumento TEXT, volume TEXT,PercRadice TEXT, PercResto TEXT, PrimoLInk  TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT,IdAutore TEXT, PRIMARY KEY (id_univoco_globale AUTOINCREMENT))';
      Database dbVuoto = await openDatabase(primoVuotoPath, version: 1, onCreate: (db, version) => db.execute(createStatement));
      await dbVuoto.close();
    }

    // Fase 2: Tenta di aprire la configurazione e il catalogo attivo.
    // Se questa parte fallisce (es. tabelle vuote dopo il primo setup), l'errore verrà catturato
    // e l'app si avvierà in modalità "non inizializzata", come da architettura.
    gDbGlobale = await openDatabase(p.join(supportDir.path, _dbGlobaleName));
    gDbGlobalePath = gDbGlobale!.path;

    final datiSistemaResult = await gDbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistemaResult.isEmpty) {
        print("INFO: DatiSistremaApp è vuota. L'utente deve eseguire il setup dal menu.");
        await gDbGlobale?.close(); // Chiudiamo il db globale che non è configurato.
        gDbGlobale = null;
        return;
    }
    
    final datiSistema = datiSistemaResult.first;
    gPercorsoPdf = datiSistema['PercorsoPdf'] as String? ?? '';
    final idCatalogoAttivo = datiSistema['id_catalogo_attivo'] as int?;
    if (idCatalogoAttivo == null) throw Exception('id_catalogo_attivo non trovato in DatiSistremaApp.');

    final catalogoInfoResult = await gDbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo], limit: 1);
    if (catalogoInfoResult.isEmpty) throw Exception('Catalogo attivo con ID $idCatalogoAttivo non trovato in elenco_cataloghi!');
    
    final catalogoInfo = catalogoInfoResult.first;
    gActiveCatalogDbName = catalogoInfo['nome_file_db'] as String;
    
    // Apri il database del catalogo
    gDatabase = await openDatabase(p.join(supportDir.path, gActiveCatalogDbName));
    gVecchioDbPath = gDatabase!.path;

    print("***** INIZIALIZZAZIONE COMPLETATA (Guardiano) *****");

  } catch (e) {
    print("### ERRORE INIZIALIZZAZIONE (Guardiano): $e ###");
    // Se c'è un errore, ci assicuriamo che i DB globali siano null per riflettere lo stato fallito
    gDbGlobale = null;
    gDatabase = null;
    rethrow;
  }
}
