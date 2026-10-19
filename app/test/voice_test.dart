import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app speaks to the user as "você" ("Verifique a ligação", "a sua
/// conta"), never as "tu". This catches "tu" forms in the UI text.

/// Never right when talking to the user.
const _tuWords = {
  'tu',
  'teu',
  'tua',
  'teus',
  'tuas',
  'contigo',
  'tens',
  'podes',
  'queres',
};

/// "tu" commands. The same words describe what something does ("a recolha
/// volta a tentar"), so they only count at the start of a sentence.
const _tuCommands = {
  'escolhe',
  'toca',
  'indica',
  'verifica',
  'experimenta',
  'guarda',
  'adiciona',
  'abre',
  'inicia',
  'confirma',
  'tenta',
  'escreve',
  'copia',
  'cola',
  'volta',
  'clica',
  'carrega',
  'liga',
  'desliga',
  'muda',
};

final _stringLiteral = RegExp(r"'((?:[^'\\]|\\.)*)'");
final _sentence = RegExp(r'(?:^|[.:!?]\s+)([A-Za-zÀ-ÿ]+)');
final _word = RegExp(r'[A-Za-zÀ-ÿ]+');

bool _speaksAsTu(String text) =>
    _word
        .allMatches(text)
        .any((w) => _tuWords.contains(w.group(0)!.toLowerCase())) ||
    _sentence
        .allMatches(text)
        .any((w) => _tuCommands.contains(w.group(1)!.toLowerCase()));

void main() {
  test('UI text uses "você", not "tu"', () {
    final found = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') ||
            line.trimLeft().startsWith('import ')) {
          continue;
        }
        for (final literal in _stringLiteral.allMatches(line)) {
          if (_speaksAsTu(literal.group(1)!)) {
            found.add('${file.path}:${i + 1}: ${literal.group(0)}');
          }
        }
      }
    }

    expect(found, isEmpty, reason: found.join('\n'));
  });
}
