import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database_utils.dart';
import 'inizializza_i_db_della_app.dart'; 
import 'CatturaDialoghi.dart';
import 'test_parametri_sistema_screen.dart';
import 'primo_test_db_screen.dart';
import 'test_base_catalogo_screen.dart';
import 'test_apertura_files_screen.dart';
import 'funzioni_variazione_dati_screen.dart';
import 'catalogazione_derivata_screen.dart';
import 'GestisciElencoCataloghi.dart';
import 'menu_delle_variazioni_db.dart';

import 'platform/opener_platform_interface.dart';
import 'platform/android_opener.dart';
import 'platform/windows_opener.dart';

String gActiveCatalogDbName = ''; 
Database? gDbGlobale;
Database? gDatabase; 
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String gDbGlobalePath = '';
String gVecchioDbPath = '';
const String gSpartitiTableName = 'spartiti';
String gPercorsoPdf = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- FIX: Abilita FTS5 su tutte le piattaforme ---
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) { // Aggiunto Android
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // --- FINE FIX ---

  if (Platform.isWindows) {
    OpenerPlatformInterface.instance = WindowsOpener();
  } else if (Platform.isAndroid) {
    OpenerPlatformInterface.instance = AndroidOpener();
  }

  runApp(const AreaDiTestApp());
}

class AreaDiTestApp extends StatelessWidget {
  const AreaDiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
  late final Future<void> _initializationFuture;

  int _selectedIndex = 0;

  final List<String> _titles = <String>[
    'Home',
    'Test Parametri Sistema',
    'Gestione Database',
    'Primo Test DB',
    'Test Base Catalogo',
    'Cattura Dialoghi',
    'Test Apertura Files',
    'Funzioni Variazione Dati',
    'Catalogazione Derivata',
  ];

  @override
  void initState() {
    super.initState();
    _initializationFuture = inizializzaIDbDellaApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final initError = snapshot.hasError ? snapshot.error.toString() : null;

        return _buildMainScaffold(context, initError);
      },
    );
  }

  Widget _buildMainScaffold(BuildContext context, String? initError) {
    final List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.settings_applications), label: 'Sistema'),
      const BottomNavigationBarItem(icon: Icon(Icons.edit_document), label: 'Gestione'),
      const BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'DB Test'),
      const BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Catalogo'),
      const BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Cattura Dialoghi'),
      const BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'Files'),
      const BottomNavigationBarItem(icon: Icon(Icons.functions), label: 'Dati'),
      const BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: 'Cat. Derivata'),
    ];
    
    final List<Widget> pages = [
      HomeScreen(initError: initError),
      TestParametriSistemaScreen(),
      const MenuDelleVariazioniDb(),
      PrimoTestDbScreen(),
      TestBaseCatalogoScreen(),
      CatturaDialoghiScreen(),
      TestAperturaFilesScreen(),
      FunzioniVariazioneDatiScreen(),
      CatalogazioneDerivataScreen(),
    ];

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
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: bottomNavItems,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedFontSize: 12,
        unselectedFontSize: 10,
      ),
    );
  }

  Future<void> _showDatiSistemaDialog(BuildContext context) async {
     if (gDbGlobale == null || !gDbGlobale!.isOpen) {
       showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database non inizializzato'),
          content: const Text('Per favore, vai alla sezione \"Gestione\" per configurare i database.'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
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
                  _buildInfoCatalogoAttivo(dialogContext),
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
                  TextSpan(text: gActiveCatalogDbName, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTableData(BuildContext context, String title, List<Map<String, dynamic>> data) {
    final textTheme = Theme.of(context).textTheme;

    Widget? actionButton;
    if (title == 'elenco_cataloghi') {
      actionButton = TextButton(onPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GestisciElencoCataloghi()));
      }, child: const Text('Gestisci'));
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
}

class HomeScreen extends StatelessWidget {
  final String? initError;
  const HomeScreen({this.initError, super.key});

  @override
  Widget build(BuildContext context) {
    if (initError != null) {
       return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(
            'Database non inizializzati. \nERRORE: $initError',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.red),
          ),
        ));
    }

    bool isDbOk = (gDatabase != null && gDatabase!.isOpen) && (gDbGlobale != null && gDbGlobale!.isOpen);
    if (isDbOk) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SelectableText(
              'Tutti i database sono stati aperti con successo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.green),
            ),
          ));
    } else {
      return const Center(
        child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SelectableText(
              'Database non pronti. Causa sconosciuta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.orange),
            ),
          ));
    }
  }
}
