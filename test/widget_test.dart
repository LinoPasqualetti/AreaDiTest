import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
                labelText: 'Numero di pagine',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _openWebPage,
              child: Text('Apri Pagina Web'),
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
}
