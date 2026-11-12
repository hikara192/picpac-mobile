# Лицензии зависимостей

Правило: каждая прямая зависимость — строка «зачем» и лицензия (ОТ-08).

## Шрифт

| Ресурс | Лицензия | Зачем | Статус |
|---|---|---|---|
| Futura PT 400/500 (`assets/fonts/`) | Проприетарный ParaType | Канонический шрифт брендбука 2025; файлы взяты с прод-активов `picpac.by` | **Требует подтверждения**: для публикации в App Store/Google Play нужна лицензия на embedding от владельца бренда |

## Flutter-приложение

| Пакет | Версия | Лицензия | Зачем |
|---|---|---|---|
| flutter_localizations | SDK | BSD-3-Clause | Локаль ru/en по умолчанию (Material/Cupertino delegates) |
| cupertino_icons | 1.x | MIT | Иконки Cupertino для iOS-паттернов |
| flutter_riverpod | 3.5.x | MIT | Единственный state-менеджер (ADR: без Bloc) |
| go_router | 18.x | BSD-3-Clause | Декларативная навигация, deep links `picpac://` |
| dio | 5.x | MIT | Единственный HTTP-клиент, интерсепторы авторизации и `Idempotency-Key` |
| freezed_annotation | 3.x | MIT | Иммутабельные модели приложения |
| json_annotation | 4.x | BSD-3-Clause | Кодоген JSON для прикладного слоя |
| drift / drift_flutter | 2.35 / 0.3 | Apache-2.0 / MIT | Локальная БД: индекс черновиков, кеш заказов, офлайн-очередь |
| path_provider | 2.x | BSD-3-Clause | Каталог документов для снапшотов черновиков |
| path | 1.9 | BSD-3-Clause | Работа с путями |
| flutter_secure_storage | 11.x | BSD-3-Clause | Токены в Keychain/Keystore |
| pdf | 3.x | Apache-2.0 | Экспорт макета в PDF 300 dpi (этап 1): `render/pdf_exporter.dart`, по одному листу, JPEG q90–92 |
| share_plus | 13.x | BSD-3-Clause | «Поделиться PDF»: системный share sheet, `core/export/pdf_share.dart` (порт `PdfSharePort`) |
| image_picker | 1.x | Apache-2.0 | Выбор фото из галереи/камеры (photo picker, без доступа ко всей библиотеке) |
| url_launcher | 6.3.x | BSD-3-Clause | Hosted-страница оплаты открывается в системном браузере (Custom Tab / Safari VC), `payments/hosted_page_launcher.dart`: карточные поля остаются у провайдера (PCI SAQ A), WebView нет |
| intl | 0.20 | BSD-3-Clause | Форматирование денег и дат по локали |
| uuid | 4.x | MIT | `Idempotency-Key` и локальные id |
| collection | 1.19 | BSD-3-Clause | Глубокое сравнение в value-объектах |
| crypto | 3.x | BSD-3-Clause | SHA-256 content-addressed ассеты |

## Нативные платформенные API (не пакеты)

| API | Платформа | Лицензия | Зачем |
|---|---|---|---|
| ImageIO / CoreGraphics / UniformTypeIdentifiers / CryptoKit | iOS 15+ | Apple SDK (системный) | HEIC→JPEG: декод в целевой размер, запись JPEG без словаря метаданных, SHA-256 выхода |
| `android.graphics.ImageDecoder` / `BitmapFactory` / `Bitmap` / `android.media.ExifInterface` | Android API 24+ | Android SDK (системный) | HEIF/JPEG декод, sRGB, запись JPEG; ориентация на API 24–27 |
| Канал `by.picpac/media` | iOS + Android | — (наш код, `ios/Runner/MediaNormalizer.swift`, `android/.../media/MediaNormalizer.kt`) | Единственная точка конвертации фото; новых pub-зависимостей нет (docs/research/hevc-pipeline.md §10) |

## Рабочие пакеты

| Пакет | Лицензия | Зачем |
|---|---|---|
| design_core (локальный) | Internal | Ядро документа: модель, команды, undo, preflight |
| api_contract (локальный) | Internal | DTO, `ApiPort`, `Money`, ошибки |
| mock_server (локальный) | Internal | Stateful mock API + PSP-симулятор |

## Dev-зависимости

| Пакет | Лицензия | Зачем |
|---|---|---|
| build_runner | BSD-3-Clause | Кодоген Drift |
| drift_dev | Apache-2.0 | Кодоген Drift |
| freezed | MIT | Генерация иммутабельных моделей |
| json_serializable | BSD-3-Clause | Генерация JSON |
| mocktail | MIT | Фейки в тестах |
| integration_test / flutter_test | BSD-3-Clause | Тесты |
| flutter_lints, lints | BSD-3-Clause | Статический анализ |
| test | BSD-3-Clause | Тесты чистых пакетов |
| http | BSD-3-Clause | Smoke-тесты mock-сервера |
