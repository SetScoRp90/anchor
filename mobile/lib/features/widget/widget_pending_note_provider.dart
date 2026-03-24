import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_pending_note_provider.g.dart';

/// Holds the note ID that the app should navigate to after a widget tap.
/// Set when the user taps the home screen widget; cleared after navigation.
@riverpod
class WidgetPendingNoteId extends _$WidgetPendingNoteId {
  @override
  String? build() => null;

  void set(String? id) => state = id;
  void clear() => state = null;
}
