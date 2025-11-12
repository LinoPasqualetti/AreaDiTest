import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // <-- FIX: Aggiunto import mancante per la classe Platform

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// --- Logica di Business e Schermate ---
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
import 'menu_delle_variazioni_db.dart'; // <-- NUOVO IMPORT

// --- Logica di apertura file specifica per piattaforma ---
import 'platform/opener_platform_interface.dart';
import 'platform/android_opener.dart';
import 'platform/windows_opener.dart';

// --- Variabili Globali ---
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

  // Inizializzazione della factory del DB per la piattaforma corrente
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (Platform.isWindows) {
    OpenerPlatformInterface.instance = WindowsOpener();
  } else if (Platform.isAndroid) {
    OpenerPlatformInterface.instance = AndroidOpener();
  }

  // L'app parte sempre, il caricamento dei DB avviene nella MainScreen
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
  int _selectedIndex = 0;
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // Chiama la funzione di inizializzazione autonoma e gestisce i risultati
    inizializzaIDbDellaApp().catchError((e) {
      if(mounted) setState(() => _initError = e.toString());
    }).whenComplete(() {
      if(mounted) setState(() => _isInitializing = false);
    });
  }

  final List<String> _titles = <String>[
    'Home',
    'Test Parametri Sistema',
    'Gestione Database', // <-- TITOLO AGGIORNATO
    'Primo Test DB',
    'Test Base Catalogo',
    'Cattura Dialoghi',
    'Test Apertura Files',
    'Funzioni Variazione Dati',
    'Catalogazione Derivata',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _showDatiSistemaDialog(BuildContext context) async {
    if (gDbGlobale == null || !gDbGlobale!.isOpen) {
       showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database non inizializzato'),
          content: const Text('Per favore, vai alla sezione \"Gestione\" per configurare i database.'), // <-- TESTO AGGIORNATO
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

  @override
  Widget build(BuildContext context) {
    final List<BottomNavigationBarItem> bottomNavItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.settings_applications), label: 'Sistema'),
      const BottomNavigationBarItem(icon: Icon(Icons.edit_document), label: 'Gestione'), // <-- ICONA E LABEL AGGIORNATE
      const BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'DB Test'),
      const BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Catalogo'),
      const BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Cattura Dialoghi'),
      const BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'Files'),
      const BottomNavigationBarItem(icon: Icon(Icons.functions), label: 'Dati'),
      const BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: 'Cat. Derivata'),
    ];
    
    final List<Widget> pages = [
      HomeScreen(initError: _initError),
      TestParametriSistemaScreen(),
      const MenuDelleVariazioniDb(), // <-- SCHERMATA SOSTITUITA
      PrimoTestDbScreen(),
      TestBaseCatalogoScreen(),
      CatturaDialoghiScreen(),
      TestAperturaFilesScreen(),
      FunzioniVariazioneDatiScreen(),
      CatalogazioneDerivataScreen(),
    ];

    if (_isInitializing) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems,
          currentIndex: 0,
        ),
      );
    }

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
        onTap: _onItemTapped,
        selectedFontSize: 12,
        unselectedFontSize: 10,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String? initError;
  const HomeScreen({this.initError, super.key});

  @override
  Widget build(BuildContext context) {
    String statusText;
    bool isDbOk = (gDatabase != null && gDatabase!.isOpen) && (gDbGlobale != null && gDbGlobale!.isOpen);
    
    String errorText = initError ?? 'Usare la sezione "Gestione" per configurare i database.';

    if (isDbOk) {
        statusText = 'Tutti i database sono stati aperti con successo.';
    } else {
        statusText = 'Database non inizializzati. \n$errorText';
    }

    return Center(
        child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SelectableText(
        statusText,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: isDbOk ? Colors.black : Colors.red),
      ),
    ));
  }
}
