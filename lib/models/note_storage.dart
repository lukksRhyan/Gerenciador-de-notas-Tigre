import 'dart:io';
import 'dart:convert';
import 'package:notas_tigre/models/nota.dart';
import 'package:notas_tigre/utils/configs.dart';

class NoteStorage {
  static String getNotesFilePath() {
    final folder = MyAppConfigs().notesFolderPath;
    return '$folder/notas_tigre.json';
  }

  static Future<List<Nota>> loadNotes() async {
    final filePath = getNotesFilePath();
    print(  'Loading notes from: $filePath'); // Linha de depuração
    final file = File(filePath);
    if (await file.exists()) {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Nota.fromJson(e)).toList();
    }
    return [];
  }

  static Future<void> saveNotes(List<Nota> notes) async {
    final filePath = getNotesFilePath();
    final file = File(filePath);
    await file.writeAsString(jsonEncode(notes.map((n) => n.toJson()).toList()));
  }
}