import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<int> getDbSizeInBytes() async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'roadsos.db');
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
  } catch (_) {}
  return 0;
}
