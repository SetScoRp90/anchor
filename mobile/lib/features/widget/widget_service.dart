import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../notes/domain/note.dart';

/// Service for managing the Android home screen widget.
/// Saves note data to shared storage so NoteWidgetProvider (Kotlin) can render it.
class WidgetService {
  static const _androidWidgetName = 'NoteWidgetProvider';
  static const _keyNoteId = 'widget_note_id';
  static const _keyNoteTitle = 'widget_note_title';
  static const _keyNoteContent = 'widget_note_content';

  /// Pins [note] to the home screen widget and triggers a redraw.
  static Future<void> pinNoteToWidget(Note note) async {
    try {
      final plainText = _extractPlainText(note.content);
      await HomeWidget.saveWidgetData<String>(_keyNoteId, note.id);
      await HomeWidget.saveWidgetData<String>(_keyNoteTitle, note.title);
      await HomeWidget.saveWidgetData<String>(
        _keyNoteContent,
        plainText.isEmpty ? '' : plainText,
      );
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('WidgetService: Failed to pin note to widget: $e');
    }
  }

  /// Extracts plain text from a Quill delta JSON string.
  /// Handles both {"ops": [...]} and plain [...] formats.
  /// Preserves checklist markers (☐/☑) for list items.
  static String _extractPlainText(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(deltaJson);
      final List<dynamic> ops;
      if (decoded is List) {
        ops = decoded;
      } else if (decoded is Map && decoded.containsKey('ops')) {
        ops = decoded['ops'] as List<dynamic>;
      } else {
        return '';
      }

      final buffer = StringBuffer();
      String pendingText = '';

      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! String) continue;
        final attrs = op['attributes'] as Map?;

        if (insert == '\n') {
          final listType = attrs?['list'] as String?;
          if (listType == 'unchecked') {
            buffer.writeln('☐ $pendingText');
          } else if (listType == 'checked') {
            buffer.writeln('☑ $pendingText');
          } else {
            buffer.writeln(pendingText);
          }
          pendingText = '';
        } else if (insert.contains('\n')) {
          final lines = insert.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (i < lines.length - 1) {
              buffer.writeln(pendingText + lines[i]);
              pendingText = '';
            } else {
              pendingText += lines[i];
            }
          }
        } else {
          pendingText += insert;
        }
      }

      if (pendingText.isNotEmpty) buffer.write(pendingText);

      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
