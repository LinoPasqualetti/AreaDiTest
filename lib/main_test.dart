import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:area_di_test/file_path_validator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Web Page Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();
  // AGGIUNGI QUESTA RIGA
  String _statusMessage = 'Pronto.';
  void _openWebPage() async {
    final String path = _pathController.text;
    final String pages = _pagesController.text;

    // Crea l'URL in base ai valori inseriti
    final String url = 'https://www.example.com/path=$path&pages=$pages';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Non è stato possibile aprire l\'URL: $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Open Web Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _pathController,
              decoration: InputDecoration(
                labelText: 'Percorso del file',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _pagesController,
              decoration: InputDecoration(
                labelText: 'Numero di pagina',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _openWebPage,
              child: Text('Apri Pagina Web'),
            ),
            ElevatedButton(
              child: Text('Apri PDF Internamente'),
              onPressed: () {
                setState(() {
                  _statusMessage = "Pulsante 'Apri PDF Internamente' premuto. Logica non implementata";
                });
                print('Pulsante "Apri PDF Internamente" premuto');
              },


            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pagesController.dispose();
    super.dispose();
  }
  void _updateStatus(String message) {
    if (mounted) setState(() => _statusMessage = message);
  }

  void _updateError(dynamic e) {
    if (mounted) setState(() => _statusMessage = 'ERRORE: ${e.toString()}');
  }
  Future<void> _VerificaFile({
    required BuildContext context,
    required String basePathDaDati,
    required String subPathDaDati,
    required String fileNameDaDati,
    required Function(String percorsoTrovato) inCasoDiSuccesso,
    required Function(String percorsoTentato) inCasoDiFallimento,
  }) async {
    String percorsoFinaleDaAprire = "N/A";
    bool risorsaEsiste = false;

    try {
      if (kIsWeb) {
        String baseUrlWeb = "http://192.168.1.100/JamsetPDF";
        String percorsoRelativo = '$subPathDaDati$fileNameDaDati'.replaceAll(r'\', '/');
        if (percorsoRelativo.startsWith('/')) {
          percorsoRelativo = percorsoRelativo.substring(1);
        }
        percorsoFinaleDaAprire = "$baseUrlWeb/${Uri.encodeFull(percorsoRelativo)}";
        print("URL da aprire: $percorsoFinaleDaAprire");
       // final response = await http.head(Uri.parse(percorsoFinaleDaAprire));
       // final response = _openWebPage;
       // risorsaEsiste = (response.statusCode == 200);
      } else {
        String basePathTecnico;
        if (Platform.isWindows) {
          basePathTecnico = r'C:\JamsetPDF';
        } else {
          basePathTecnico = '/storage/emulated/0/JamsetPDF';
        }

        FilePathResult risultatoNativo = await ValidaPercorso.checkGenericFilePath(
          basePath: basePathTecnico,
          subPath: subPathDaDati,
          fileNameWithExtension: fileNameDaDati,
        );
        risorsaEsiste = risultatoNativo.isSuccess;
        percorsoFinaleDaAprire = risultatoNativo.fullPath ?? "Percorso non generato";
      }
    } catch (e) {
      percorsoFinaleDaAprire = "Errore: $e";
      risorsaEsiste = false;
    }

    if (risorsaEsiste) {
      inCasoDiSuccesso(percorsoFinaleDaAprire);
    } else {
      inCasoDiFallimento(percorsoFinaleDaAprire);
    }
  }
}
