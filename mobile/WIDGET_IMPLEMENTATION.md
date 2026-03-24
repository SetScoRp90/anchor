# Реализация виджета рабочего стола (Android)

Виджет позволяет закрепить любую заметку на рабочем столе Android. Показывает заголовок и содержимое заметки, при нажатии открывает её в приложении.

---

## Обзор архитектуры

```
Flutter (Dart)                         Android (Kotlin)
──────────────────────────────         ──────────────────────────────
WidgetService.pinNoteToWidget()  ──►   HomeWidgetPlugin (SharedPreferences)
  └─ HomeWidget.saveWidgetData()       └─ NoteWidgetProvider.onUpdate()
  └─ HomeWidget.updateWidget()               └─ RemoteViews → widget_note.xml
```

Данные передаются через `SharedPreferences` с помощью пакета `home_widget`. Flutter записывает данные заметки, Android читает и отображает их.

---

## 1. Зависимости

### `pubspec.yaml`

```yaml
dependencies:
  home_widget: ^0.7.0
```

---

## 2. Flutter-часть (Dart)

### 2.1 Сервис сохранения данных виджета

**Файл:** `lib/features/widget/widget_service.dart`

Отвечает за запись данных заметки в общее хранилище и принудительное обновление виджета.

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../notes/domain/note.dart';

class WidgetService {
  static const _androidWidgetName = 'NoteWidgetProvider';
  static const _keyNoteId      = 'widget_note_id';
  static const _keyNoteTitle   = 'widget_note_title';
  static const _keyNoteContent = 'widget_note_content';

  static Future<void> pinNoteToWidget(Note note) async {
    try {
      final plainText = _extractPlainText(note.content);
      await HomeWidget.saveWidgetData<String>(_keyNoteId,      note.id);
      await HomeWidget.saveWidgetData<String>(_keyNoteTitle,   note.title);
      await HomeWidget.saveWidgetData<String>(_keyNoteContent, plainText);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('WidgetService: Failed to pin note to widget: $e');
    }
  }

  /// Извлекает plain-text из Quill delta JSON.
  ///
  /// Важно: редактор сохраняет контент в формате {"ops": [...]},
  /// а не как plain список [...]. Поэтому необходимо обрабатывать оба варианта.
  ///
  /// Для элементов чеклиста добавляются символы ☐ / ☑.
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

      final buffer     = StringBuffer();
      String pending   = '';

      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! String) continue;
        final attrs = op['attributes'] as Map?;

        if (insert == '\n') {
          final listType = attrs?['list'] as String?;
          if      (listType == 'unchecked') buffer.writeln('☐ $pending');
          else if (listType == 'checked')   buffer.writeln('☑ $pending');
          else                              buffer.writeln(pending);
          pending = '';
        } else if (insert.contains('\n')) {
          final lines = insert.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (i < lines.length - 1) { buffer.writeln(pending + lines[i]); pending = ''; }
            else                      { pending += lines[i]; }
          }
        } else {
          pending += insert;
        }
      }

      if (pending.isNotEmpty) buffer.write(pending);
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
```

**Ключевые решённые проблемы:**

| Проблема | Причина | Решение |
|---|---|---|
| Контент виджета пустой | `getContent()` в редакторе возвращает `{"ops":[...]}`, а код делал `as List` → `CastError` молча поглощался `catch` | Обработка обоих форматов: `List` и `Map{"ops"}` |
| Чеклист показывается как plain text | `Document.toPlainText()` игнорирует атрибут `list` | Ручной обход ops с добавлением символов `☐`/`☑` |

---

### 2.2 Провайдер состояния (навигация по тапу на виджет)

**Файл:** `lib/features/widget/widget_pending_note_provider.dart`

Хранит `noteId`, к которому нужно перейти после тапа на виджет. Очищается после навигации.

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'widget_pending_note_provider.g.dart';

@riverpod
class WidgetPendingNoteId extends _$WidgetPendingNoteId {
  @override
  String? build() => null;

  void set(String? id) => state = id;
  void clear() => state = null;
}
```

> **Важно:** В Riverpod 3 класс `StateProvider` удалён. Необходимо использовать `@riverpod`-аннотацию с `Notifier`. После изменения файла нужно запустить кодогенерацию:
> ```
> dart run build_runner build --delete-conflicting-outputs
> ```

---

### 2.3 Вызов закрепления из экрана редактирования заметки

**Файл:** `lib/features/notes/presentation/note_edit_screen.dart`

```dart
Future<void> _pinToWidget() async {
  final note = _existingNote;
  if (note == null) return;

  if (_hasUnsavedChanges) await _autoSave();

  final title   = _titleController.text.trim();
  final content = _editorKey.currentState?.getContent() ?? note.content ?? '';
  final snapshot = note.copyWith(
    title:   title.isNotEmpty ? title : note.title,
    content: content,
  );

  await WidgetService.pinNoteToWidget(snapshot);

  if (mounted) {
    AppSnackbar.showSuccess(context, message: 'Note pinned to widget');
  }
}
```

---

## 3. Android-часть (Kotlin + XML)

### 3.1 AppWidgetProvider

**Файл:** `android/app/src/main/kotlin/com/zhfahim/anchor/NoteWidgetProvider.kt`

Читает данные из SharedPreferences и обновляет `RemoteViews`.

```kotlin
class NoteWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val noteId      = widgetData.getString("widget_note_id", null)
            val noteTitle   = widgetData.getString("widget_note_title",   null)
                ?: context.getString(R.string.widget_no_note_title)
            val noteContent = widgetData.getString("widget_note_content", null)
                ?: context.getString(R.string.widget_no_note_content)

            val views = RemoteViews(context.packageName, R.layout.widget_note)
            views.setTextViewText(R.id.widget_note_title,   noteTitle)
            views.setTextViewText(R.id.widget_note_content, noteContent)

            // При тапе — deep link к заметке или открытие главного экрана
            val pendingIntent = if (noteId != null) {
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java,
                    Uri.parse("anchor://open?noteId=$noteId")
                )
            } else {
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                PendingIntent.getActivity(context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }

            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
```

---

### 3.2 Макет виджета

**Файл:** `android/app/src/main/res/layout/widget_note.xml`

```xml
<LinearLayout android:id="@+id/widget_container"
    android:background="@drawable/widget_background"
    android:orientation="vertical" android:padding="16dp" ...>

    <!-- Строка бренда: иконка + название приложения + иконка булавки -->
    <LinearLayout android:orientation="horizontal" ...>
        <ImageView android:src="@mipmap/launcher_icon" android:layout_width="14dp" ... />
        <TextView android:text="@string/app_name" android:textColor="#80FFFFFF" android:textSize="11sp" ... />
        <ImageView android:id="@+id/widget_pin_indicator" android:src="@drawable/ic_widget_pin" ... />
    </LinearLayout>

    <!-- Заголовок заметки -->
    <TextView android:id="@+id/widget_note_title"
        android:textColor="#FFFFFF" android:textSize="15sp" android:textStyle="bold"
        android:maxLines="2" android:ellipsize="end" ... />

    <!-- Содержимое заметки -->
    <TextView android:id="@+id/widget_note_content"
        android:textColor="#CCFFFFFF" android:textSize="13sp"
        android:maxLines="5" android:ellipsize="end"
        android:layout_height="0dp" android:layout_weight="1" ... />
</LinearLayout>
```

---

### 3.3 Конфигурация виджета

**Файл:** `android/app/src/main/res/xml/note_widget_info.xml`

```xml
<appwidget-provider
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="3"
    android:targetCellHeight="2"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/widget_note"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
```

---

### 3.4 Фон виджета

**Файл:** `android/app/src/main/res/drawable/widget_background.xml`

```xml
<shape android:shape="rectangle">
    <solid android:color="#E61A1A2E" />  <!-- тёмно-синий, ~90% непрозрачности -->
    <corners android:radius="16dp" />
</shape>
```

---

### 3.5 Регистрация в AndroidManifest.xml

Два добавления в `android/app/src/main/AndroidManifest.xml`:

**1. Deep link для открытия заметки по тапу на виджет** (внутри `<activity>`):
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:scheme="anchor" android:host="open" />
</intent-filter>
```

**2. Receiver для виджета** (на уровне `<application>`):
```xml
<receiver android:name=".NoteWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/note_widget_info" />
</receiver>
```

---

## 4. Исправление сборки (`build.gradle.kts`)

Исходный код падал с `null cannot be cast to non-null type kotlin.String` при отсутствии файла `key.properties` (Release signing config).

**Было:**
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String  // NPE если файла нет
        ...
    }
}
```

**Стало:**
```kotlin
signingConfigs {
    if (keystorePropertiesFile.exists()) {
        create("release") { ... }
    }
}

buildTypes {
    release {
        signingConfig = if (keystorePropertiesFile.exists())
            signingConfigs.getByName("release")
        else
            signingConfigs.getByName("debug")   // fallback для тестовых сборок
    }
}
```

---

## 5. Строки ресурсов

**Файл:** `android/app/src/main/res/values/strings.xml` — должен содержать:

```xml
<string name="widget_no_note_title">No note selected</string>
<string name="widget_no_note_content">Open a note and tap the pin button to show it here.</string>
```

---

## 6. Сборка и установка

```bash
# Кодогенерация (если менялись провайдеры)
dart run build_runner build --delete-conflicting-outputs

# Сборка APK
flutter build apk

# Если уже установлена другая версия — сначала удалить (конфликт подписи)
adb uninstall com.zhfahim.anchor

# Установка
flutter install
# или напрямую через adb:
# adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. Использование виджета

1. Открыть заметку в приложении
2. Нажать кнопку **булавки** (pin) в тулбаре
3. Появится уведомление _"Note pinned to widget"_
4. Добавить виджет **Anchor Notes** на рабочий стол Android (долгое нажатие → Виджеты)
5. При тапе на виджет приложение откроется сразу на закреплённой заметке
