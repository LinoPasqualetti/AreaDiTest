import 'package:flutter/material.dart';

// --- Schermate di gestione ---
import 'GestisciElencoCataloghi.dart';
// NOTA: Le seguenti schermate verranno create nei prossimi passaggi.
// import 'varia_datisistremaapp.dart';
// import 'lista_spartiti_catalogo.dart';


/// Menu centrale per accedere alle varie sezioni di gestione dei database.
/// Sostituisce la vecchia schermata di "Setup".
class MenuDelleVariazioniDb extends StatelessWidget {
  const MenuDelleVariazioniDb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _MenuItem(
            icon: Icons.settings_applications_sharp,
            title: 'Dati di Sistema',
            subtitle: 'Modifica il percorso dei PDF e imposta il catalogo attivo.',
            onTap: () {
              // TODO: Creare e navigare a VariaDatiSistremaAppScreen
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Schermata "VariaDatiSistremaApp" da implementare.'),
                backgroundColor: Colors.orange,
              ));
            },
          ),
          const Divider(),
          _MenuItem(
            icon: Icons.inventory_2_outlined,
            title: 'Elenco Cataloghi',
            subtitle: 'Aggiungi, modifica o elimina i database dei cataloghi.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GestisciElencoCataloghi()),
              );
            },
          ),
          const Divider(),
          _MenuItem(
            icon: Icons.library_music_outlined,
            title: 'Spartiti del Catalogo Attivo',
            subtitle: 'Visualizza e gestisci i brani nel database attualmente in uso.',
            onTap: () {
              // TODO: Creare e navigare a ListaSpartitiCatalogoScreen
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Schermata "ListaSpartitiCatalogo" da implementare.'),
                 backgroundColor: Colors.orange,
              ));
            },
          ),
        ],
      ),
    );
  }
}

/// Widget helper per creare una voce di menu consistente.
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: Icon(icon, size: 40.0, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}
