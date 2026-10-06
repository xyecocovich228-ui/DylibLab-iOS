# DylibLab — iOS стенд для теста .dylib менюшек

Горизонтальное пустое приложение для проверки менюшек **без вшивания в игру**.
Кидаешь `.dylib` → стенд делает `dlopen` → в логе видно **что сломалось, почему и на каком моменте**.

![platform](https://img.shields.io/badge/platform-iOS%2015%2B-blue) ![orientation](https://img.shields.io/badge/orientation-landscape-green)

## Что умеет

- **Импорт .dylib** через Files / AirDrop / iTunes Sharing → `Documents/Dylibs`
- **Пошаговый лог загрузки** (5 моментов):
  1. файл (путь, размер)
  2. Mach-O / архитектура (сразу видно `x86_64` вместо `arm64`)
  3. подпись / джейл
  4. `dlopen` + расшифровка `dlerror` на русском
  5. оверлей (создало ли меню `UIWindow`)
- **Лог-меню с кнопкой «Копировать»** — весь лог одним тапом в буфер + фильтры INFO/OK/WARN/ERR + Поделиться
- **Тест оверлея** — красная плавающая кнопка с драгом, проверка что `UIWindow alert+1` и тачи работают
- **Файловый менеджер** — размер, arch, загрузить/выгрузить/удалить
- **Хелп** — таблица ошибок, как собирать и подписывать dylib
- **Только landscape** — `UIInterfaceOrientations = LandscapeLeft/Right`
- **Автозагрузка** при старте (переключатель)

## Как получить .ipa

1. Открой вкладку **Actions** → **Build unsigned IPA** → последний зелёный ран → **Artifacts: DylibLab-unsigned-ipa**.
2. Или **Releases** → `build-N` → `DylibLab-unsigned.ipa`.
3. IPA **unsigned** (собран с `CODE_SIGNING_ALLOWED=NO`) — подпиши перед установкой:
   - Sideloadly / AltStore / SideStore
   - `codesign` + `ios-deploy`
   - TrollStore (можно без подписи)

## Как тестить менюшку

1. Установи IPA, открой (держи девайс горизонтально).
2. **Стенд → Импорт .dylib** → выбери файл.
3. Смотри **Логи**:
   - `Момент 4/5 ✓ dlopen ВЕРНУЛ ХЭНДЛ` — хорошо.
   - `Момент 4/5 ✕ DLOPEN УПАЛ: ...` + строка **Причина** — что чинить.
   - `Момент 5/5 ✓ меню создало окна` — меню живо.
4. Не видно меню, но dlopen ок → жми **Тест оверлея**. Красная кнопка таскается — значит копай своё меню (frame/hidden/windowLevel/main thread).
5. **Копировать лог** → отправь автору меню.

## Частые ошибки

| dlerror | Что значит | Что делать |
|---|---|---|
| `code signature invalid` | нет подписи | `codesign -f -s "Apple Development: ..." menu.dylib` или Embed & Sign + пересборка IPA |
| `no suitable image` | нет arm64 или нет подписи | смотри Момент 2/5 в логе |
| `library not loaded` | тянет зависимости | `otool -L menu.dylib` → доложи рядом |
| `symbol not found` | ищет символы игры | отложи поиск до запуска игры, в стенде это ок |
| молча нет окна | constructor пуст / не main thread | UI только на main, `windowLevel = .alert+1` |

## Шаблон

Папка `DylibTemplate/MenuTemplate.m` — минимальное красное меню. Сборка:

```bash
xcrun -sdk iphoneos clang -arch arm64 -dynamiclib \
  -framework UIKit -framework Foundation \
  MenuTemplate.m -o menu.dylib
```

## Проект

- Bundle ID: `com.dyliblab.harness`, iOS 15.0+, Swift 5, UIKit, без сториборда
- Структура: `DylibLab/Core` (Logger, DylibLoader, MachoInspector, OverlayHost), `DylibLab/UI` (4 вкладки)
- Иконка: зелёная `DL` (Assets.xcassets)
