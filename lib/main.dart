import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:area_di_test/database_utils.dart';

import 'package:area_di_test/CatturaDialoghi.dart';
import 'package:area_di_test/test_parametri_sistema_screen.dart';
import 'package:area_di_test/primo_test_db_screen.dart';
import 'package:area_di_test/test_base_catalogo_screen.dart';
import 'package:area_di_test/test_apertura_files_screen.dart';
import 'package:area_di_test/funzioni_variazione_dati_screen.dart';
import 'package:area_di_test/catalogazione_derivata_screen.dart';

const bool _useExternalDb = false; 
const String _externalDbPath = '/storage/emulated/0/Download/JamsetDB.db';
const String _internalDbName = 'VecchioDb.db';

Database? gDatabase;
String gDatabaseName = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    if (_useExternalDb && !kIsWeb) {
      gDatabase = await openDatabase(_externalDbPath);
      gDatabaseName = p.basename(_externalDbPath);
    } else {
      gDatabase = await initDatabase(_internalDbName);
      gDatabaseName = _internalDbName;
    }
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

  // Le pagine vengono create una sola volta e messe in una lista
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40.0,
        title: SelectableText(_titles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // FIX: Usato IndexedStack per preservare lo stato degli schermi
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
    return const Center(
        child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        'Database aperto all\'avvio.\nPronto per essere usato nelle altre schermate.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18),
      ),
    ));
  }
}
