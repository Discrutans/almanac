# Иконка приложения

Исходники редактируются вручную и устанавливаются скриптом:

```bash
python tool/install_app_icons.py path/to/app_icon.png path/to/app_icon_foreground.png
dart run flutter_launcher_icons
```

- `app_icon.png` — полная иконка 1024×1024 (с фоном)
- `app_icon_foreground.png` — foreground для adaptive icon (прозрачный фон)
- Android splash (`res/drawable/splash_icon.png`) берётся из foreground без фона;
  цвет экрана — `@color/splash_background` (светлая/тёмная тема).
