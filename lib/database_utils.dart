export 'database_utils_io.dart' // Esporta questo di default
    if (dart.library.html) 'database_utils_web.dart'; // Ma se sei sul web, esporta questo.
