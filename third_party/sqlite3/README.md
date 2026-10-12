# SQLite amalgamation (offline build)

Сборка `sqlite3` больше **не скачивает** prebuilt-библиотеки с GitHub.
Исходник компилируется локально через Dart hooks.

## Один раз (нужен интернет к sqlite.org)

```powershell
cd D:\proect_\calendar\almanac
powershell -ExecutionPolicy Bypass -File tool\setup_sqlite_amalgamation.ps1
```

Скрипт кладёт `sqlite3.c` и `sqlite3.h` в эту папку.

После этого:

```powershell
flutter pub get
flutter build apk --release
```

Если сборка падает с `classes.dex ... used by another process`, закройте другие `flutter`/`gradle` процессы или выполните `flutter clean`.
