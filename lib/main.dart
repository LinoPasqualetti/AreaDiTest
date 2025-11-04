import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'database_utils.dart';

// --- Schermate dell'app ---
import 'CatturaDialoghi.dart';
import 'test_parametri_sistema_screen.dart';
import 'primo_test_db_screen.dart';
import 'test_base_catalogo_screen.dart';
import 'test_apertura_files_screen.dart';
import 'funzioni_variazione_dati_screen.dart';
import 'catalogazione_derivata_screen.dart';

// --- Logica di apertura file specifica per piattaforma ---
import 'platform/opener_platform_interface.dart';
import 'platform/android_opener.dart';
import 'platform/windows_opener.dart';


// --- Gestione Database e Variabili Globali ---
const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';

Database? gDbGlobale;
Database? gDatabase;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // CHIAVE DI NAVIGAZIONE GLOBALE

String gDbGlobalePath = '';
String gVecchioDbPath = '';
String gSpartitiTableName = '';
String gPercorsoPdf = ''; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- INIZIALIZZAZIONE SPECIFICA PER PIATTAFORMA ---
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    gSpartitiTableName = 'spartiti_andr';
    // OpenerPlatformInterface.instance = WebOpener(); // Esempio per il futuro
  } else if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    gSpartitiTableName = 'spartiti';
    OpenerPlatformInterface.instance = WindowsOpener(); // Inizializzazione per Windows
  } else if (Platform.isAndroid) {
    gSpartitiTableName = 'spartiti_andr';
    OpenerPlatformInterface.instance = AndroidOpener(); // Inizializzazione per Android
  } else { // Altre piattaforme desktop/mobile
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    gSpartitiTableName = 'spartiti_andr';
    // OpenerPlatformInterface.instance = UnsupportedOpener(); // Esempio per il futuro
  }

  print("Piattaforma: ${Platform.operatingSystem}. Tabella spartiti selezionata: '$gSpartitiTableName'");

  // Apertura di tutti i database all'avvio
  try {
    gDbGlobale = await initDatabase(_dbGlobaleName);
    gDbGlobalePath = gDbGlobale!.path;

    gDatabase = await initDatabase(_vecchioDbName);
    gVecchioDbPath = gDatabase!.path;
    
    // Legge il percorso del PDF viewer dal DB
    final datiSistema = await gDbGlobale!.query('DatiSistremaApp', limit: 1);
    if (datiSistema.isNotEmpty && datiSistema.first['PercorsoPdf'] != null) {
      gPercorsoPdf = datiSistema.first['PercorsoPdf'] as String;
    }

    print("Database aperti con successo:");
    print("- DBGlobale in: $gDbGlobalePath");
    print("- VecchioDB in: $gVecchioDbPath");
    print("- Percorso PDF globale: $gPercorsoPdf");

  } catch (e) {
    print("ERRORE CRITICO APERTURA DB: $e");
  }

  runApp(const AreaDiTestApp());
}

class AreaDiTestApp extends StatelessWidget {
  const AreaDiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // COLLEGA LA CHIAVE GLOBALE
      title: 'Area di Test - Base Pulita',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const <Widget>[
    HomeScreen(),
    TestParametriSistemaScreen(),
    PrimoTestDbScreen(),
    TestBaseCatalogoScreen(),
    CatturaDialoghiScreen(),
    TestAperturaFilesScreen(),
    FunzioniVariazioneDatiScreen(),
    CatalogazioneDerivataScreen(),
  ];

  static const List<String> _titles = <String>[
    'main',
    'test_parametri_sistema_screen',
    'primo_test_db_screen',
    'test_base_catalogo_screen',
    'CatturaDialoghi',
    'test_apertura_files_screen',
    'funzioni_variazione_dati_screen',
    'catalogazione_derivata_screen',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Funzione parametrizzata per forzare il riallineamento di un database.
  Future<void> _forceRiallineamento(BuildContext context, String dbName) async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Riallineamento'),
        content: Text(
            'Stai per cancellare il database \'$dbName\' dal dispositivo. L\'app verrà chiusa. \n\nAl riavvio, il database verrà ricreato dalla versione presente negli asset. \n\nProcedere?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Conferma e Chiudi App')),
        ],
      ),
    );

    if (confermato == true && !kIsWeb) {
      try {
        // Chiude il DB corretto prima di cancellarlo
        if (dbName == _dbGlobaleName) {
          await gDbGlobale?.close();
        } else if (dbName == _vecchioDbName) {
          await gDatabase?.close();
        }

        final supportDir = await getApplicationSupportDirectory();
        final path = p.join(supportDir.path, dbName);
        final dbFile = File(path);
        if (await dbFile.exists()) {
          await dbFile.delete();
          print("RIALLINEAMENTO FORZATO: Database '$dbName' eliminato.");
        }
        SystemNavigator.pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore durante l'eliminazione: $e")));
      }
    }
  }

  /// Mostra un dialogo con i dati di sistema dal database globale.
  Future<void> _showDatiSistemaDialog(BuildContext context) async {
    if (gDbGlobale == null || !gDbGlobale!.isOpen) {
      // ... (codice di errore invariato)
      return;
    }

    final datiSistema = await gDbGlobale!.query('DatiSistremaApp');
    final elencoCataloghi = await gDbGlobale!.query('elenco_cataloghi');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Parametri di Sistema'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTableData(dialogContext, 'DatiSistremaApp', datiSistema),
                  const SizedBox(height: 16),
                  _buildTableData(dialogContext, 'elenco_cataloghi', elencoCataloghi),
                  const Divider(height: 32),
                  // NUOVA SEZIONE: Catalogo Attivo
                  _buildInfoCatalogoAttivo(dialogContext),
                  const Divider(height: 32),
                  Text('Strumenti Sviluppatore', style: Theme.of(dialogContext).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _forceRiallineamento(context, _dbGlobaleName);
                    },
                    icon: const Icon(Icons.storage_rounded, size: 18),
                    label: const Text('Riallinea DB Globale'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _forceRiallineamento(context, _vecchioDbName);
                    },
                    icon: const Icon(Icons.dns_rounded, size: 18),
                    label: const Text('Riallinea Vecchio DB'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Chiudi')),
          ],
        );
      },
    );
  }

  /// Widget helper per visualizzare le info sul catalogo attivo.
  Widget _buildInfoCatalogoAttivo(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catalogo Attivo', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText.rich(
                TextSpan(style: textTheme.bodyMedium, children: <TextSpan>[
                  const TextSpan(text: 'Database: '),
                  TextSpan(text: _vecchioDbName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 4),
              SelectableText.rich(
                TextSpan(style: textTheme.bodyMedium, children: <TextSpan>[
                  const TextSpan(text: 'Tabella in uso: '),
                  TextSpan(text: gSpartitiTableName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }


  /// Widget helper per visualizzare i dati di una tabella.
  Widget _buildTableData(BuildContext context, String title, List<Map<String, dynamic>> data) {
    final textTheme = Theme.of(context).textTheme;

    Widget? actionButton;
    if (title == 'DatiSistremaApp') {
      actionButton = TextButton(onPressed: () {}, child: const Text('Varia'));
    } else if (title == 'elenco_cataloghi') {
      actionButton = TextButton(onPressed: () {}, child: const Text('Tratta'));
    }

    if (data.isEmpty) {
      return Text('$title: Nessun dato trovato.', style: textTheme.titleMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (actionButton != null) actionButton,
          ],
        ),
        const SizedBox(height: 8),
        for (final row in data)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: row.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: SelectableText.rich(
                    TextSpan(
                      style: textTheme.bodyMedium,
                      children: <TextSpan>[
                        TextSpan(text: '${entry.key}: '),
                        TextSpan(text: entry.value?.toString() ?? 'NULL', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40.0,
        title: SelectableText(_titles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Mostra Parametri di Sistema',
            onPressed: () => _showDatiSistemaDialog(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_applications), label: 'Sistema'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'DB Test'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Catalogo'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Cattura Dialoghi'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.functions), label: 'Dati'),
          BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: 'Cat. Derivata'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedFontSize: 12,
        unselectedFontSize: 10,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    String statusText = (gDatabase != null && gDatabase!.isOpen) && (gDbGlobale != null && gDbGlobale!.isOpen)
        ? 'Tutti i database sono stati aperti con successo all\'avvio.\nPronti per essere usati nelle altre schermate.'
        : 'ERRORE: Uno o piu database non sono stati aperti correttamente.';

    return Center(
        child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SelectableText(
        statusText,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: (gDatabase != null && gDatabase!.isOpen) ? Colors.black : Colors.red),
      ),
    ));
  }
}
