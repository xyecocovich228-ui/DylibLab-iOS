# Inject — встройка .dylib внутрь IPA

Если нет Mac и `codesign` недоступен, проще не подписывать dylib отдельно,
а вшить его в IPA ДО подписи — тогда Sideloadly / ESign / Feather подпишет
приложение и dylib одним сертификатом за раз, и `dlopen` из bundle пройдёт.

## Как пользоваться

1. Положи `.dylib` файлы в эту папку (`Inject/*.dylib`), закоммить и запушь в `main`.
2. Дождись зелёного Actions → забери IPA из Artifacts / Releases.
3. Установи этот IPA через Sideloadly / AltStore / Feather / ESign.
4. В DylibLab иди в Файлы — встроенные dylib уже лежат в bundle, жми Загрузить.
   Грузи именно встроенную копию (путь `.../DylibLab.app/Frameworks/...`),
   а не копию из `Documents` — у неё подпись совпадёт с приложением.

## Что делает сборка

Шаг `Package unsigned IPA` в `.github/workflows/build-ipa.yml`:
- собирает `.app` без подписи,
- копирует `Inject/*.dylib` в `Payload/DylibLab.app/Frameworks/`,
- пакует IPA.

Sideloadly при установке подписывает всё вложенное в `Frameworks` тем же Team ID.
