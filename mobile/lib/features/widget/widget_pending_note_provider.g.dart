// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_pending_note_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the note ID that the app should navigate to after a widget tap.
/// Set when the user taps the home screen widget; cleared after navigation.

@ProviderFor(WidgetPendingNoteId)
const widgetPendingNoteIdProvider = WidgetPendingNoteIdProvider._();

/// Holds the note ID that the app should navigate to after a widget tap.
/// Set when the user taps the home screen widget; cleared after navigation.
final class WidgetPendingNoteIdProvider
    extends $NotifierProvider<WidgetPendingNoteId, String?> {
  /// Holds the note ID that the app should navigate to after a widget tap.
  /// Set when the user taps the home screen widget; cleared after navigation.
  const WidgetPendingNoteIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'widgetPendingNoteIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$widgetPendingNoteIdHash();

  @$internal
  @override
  WidgetPendingNoteId create() => WidgetPendingNoteId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$widgetPendingNoteIdHash() =>
    r'e1ef898cc16cc806bb5984593dc99ffb0f56634e';

/// Holds the note ID that the app should navigate to after a widget tap.
/// Set when the user taps the home screen widget; cleared after navigation.

abstract class _$WidgetPendingNoteId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
