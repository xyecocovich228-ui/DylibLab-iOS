# Шаблон тестовой .dylib для DylibLab

## Сборка на Mac (Xcode Command Line Tools)

```bash
xcrun -sdk iphoneos clang -arch arm64 -dynamiclib \
  -framework UIKit -framework Foundation \
  MenuTemplate.m -o menu.dylib

# Проверка arch:
file menu.dylib
# должно быть: Mach-O 64-bit dynamically linked shared library arm64

# Проверка зависимостей:
otool -L menu.dylib

# Подпись тем же сертификатом что и приложение (для нон-джейл):
codesign -f -s "Apple Development: xxx@yyy (TEAMID)" menu.dylib
codesign -d --verbose=4 menu.dylib
```

## Тест в стенде

1. AirDrop / Files → открыть `menu.dylib` в DylibLab → Импорт.
2. Стенд сам вызовет `dlopen`, в логе должно быть:
   - `Момент 4/5 ✓ dlopen ВЕРНУЛ ХЭНДЛ`
   - `[MenuTemplate] constructor вызван`
   - `Момент 5/5 ✓ меню создало окна`
3. На экране появится красное окно `MENU v1`.
4. Кнопка `⎘ Копировать лог` → отправь лог автору если что-то упало.

## Своя менюшка

- Весь UI только на main thread.
- Окно: `UIWindow(windowScene:)` + `windowLevel = .alert + 1`.
- Не блокируй constructor — только `dispatch_async`.
- Проверяй landscape: ширина > высоты.
