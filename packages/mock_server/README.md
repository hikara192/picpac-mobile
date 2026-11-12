# mock_server — stateful mock API и PSP-симулятор PicPac

Чистый Dart (Shelf), без Flutter и без сети наружу. Один и тот же сервер
используется:

- приложением — в процессе (`API_MODE=embedded`) и как отдельный процесс
  (`scripts/dev-api.sh`, `scripts/dev.sh`);
- контрактными тестами — через `createHandler` без сокетов;
- QA и демо — через `bin/server.dart` и `/v1/mock/*`.

Деньги — только `int` в минорных единицах + валюта. Цена, скидка, доставка, ETA,
preflight и промокоды считаются на сервере. `paymentStatus` и
`fulfillmentStatus` — независимые оси.

## Запуск

```sh
# из корня picpac-mobile
dart run packages/mock_server/bin/server.dart --port 8080
# или
./scripts/dev-api.sh

# другой порт / явные сиды
dart run packages/mock_server/bin/server.dart --port 9090 \
  --seed packages/mock_server/seeds
```

`GET /health` → `{"status":"ok","seededAt":"2026-11-09"}`.
`Ctrl+C` (SIGINT/SIGTERM) закрывает сокет gracefully.

В приложении сервер поднимается сам: `scripts/run.sh` → `API_MODE=embedded`.
Сиды тогда берутся из сгенерированной копии (`lib/src/seeds.g.dart`), потому что
файлов пакета на устройстве нет.

## Тестовые учётки и промокоды

| Роль | Email | Пароль |
|---|---|---|
| `customer` | `customer@picpac.test` | `Test1234` |
| `support_agent` | `support@picpac.test` | `Test1234` |

- Гость: `POST /v1/auth/anonymous` → роль `guest` (каталог, черновики, корзина;
  checkout и заказы → `403 forbidden`).
- Одноразовый код: `POST /v1/auth/verify {"challengeId":"challenge_demo","code":"0000"}`
  → сессия клиента. Другой код → `422`, неизвестный challenge → `404`,
  использованный/просроченный/сожжённый пятью ошибками → `410 challenge_expired`.
- Промокоды: `TEST10` (−10 % на товары), `PIC100` (100 %: итог 0, заказ сразу
  `paid`, `PaymentIntent` не создаётся).

Пароли в сидах хранятся только как PBKDF2-HMAC-SHA256 (соль + 100k итераций);
открытый текст есть лишь здесь и в тестах.

## Демо-сценарии

```sh
# гость
curl -s -X POST localhost:8080/v1/auth/anonymous \
  -H 'content-type: application/json' -d '{"locale":"ru"}'

# каталог и цена
curl -s localhost:8080/v1/catalog
curl -s -X POST localhost:8080/v1/price -H 'content-type: application/json' \
  -d '{"productId":"photo_print","formatId":"10x15","spreadsCount":10,"promoCode":"TEST10"}'

# демо-контролы требуют support_agent (MOCK_ALLOW_ANONYMOUS=1 снимает проверку)
SUPPORT=$(curl -s -X POST localhost:8080/v1/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"support@picpac.test","password":"Test1234"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

# сценарии PSP
curl -s -X POST localhost:8080/v1/mock/psp/simulate \
  -H "authorization: Bearer $SUPPORT" -H 'content-type: application/json' \
  -d '{"scenario":"timeout_then_webhook","intentId":"int_0001"}'

# обрыв загрузки
curl -s -X POST localhost:8080/v1/mock/faults \
  -H "authorization: Bearer $SUPPORT" -H 'content-type: application/json' \
  -d '{"mode":"upload_interrupt"}'

# сброс состояния между демо
curl -s -X POST localhost:8080/v1/mock/reset -H "authorization: Bearer $SUPPORT"
```

### Подписанный вебхук PSP

Вебхук принимается только с `X-Psp-Timestamp` (ISO-8601 UTC, ±5 минут) и
`X-Psp-Signature` = hex HMAC-SHA256 секрета над строкой
`<timestamp>\n<body>`. Секрет — `PSP_WEBHOOK_SECRET` (env или `--dart-define`).
Без секрета mock берёт детерминированный dev-секрет и пишет в лог
`insecure dev secret`; для продакшен-подобного прогона это запрещено.

```sh
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BODY='{"eventId":"evt-1","intentId":"int_0001","type":"payment.succeeded"}'
SIG=$(printf '%s\n%s' "$TS" "$BODY" \
  | openssl dgst -sha256 -hmac "picpac-mock-insecure-dev-webhook-secret" -hex \
  | sed 's/^.*= //')
curl -s -X POST localhost:8080/v1/webhooks/psp/bepaid \
  -H "content-type: application/json" \
  -H "x-psp-timestamp: $TS" -H "x-psp-signature: $SIG" -d "$BODY"
```
```

## Сиды

`seeds/*.json` — нормализованный снимок `ALLINFO/parsed-web-full/data`:

- `catalog.json` — 4 продукта, 7 форматов, шаблоны (`single_10x15`, `duo_10x15`,
  `quad_10x15`, `single_3x4`, `single_sheet`, `spread_full`), цены, опции,
  правила цены книг;
- `delivery.json` — 6 способов получения, точка самовывоза, сетка слотов;
- `payments.json` — методы BY/RU и sandbox-провайдеры;
- `promotions.json` — `TEST10`, `PIC100`;
- `accounts.json` — тестовые аккаунты и challenge;
- `inspiration.json` — 14 идей ленты (геометрия шаблонов, теги, популярность) и
  форматы, которые их поддерживают. При загрузке шаблоны идей дописываются в
  allow-list этих форматов, поэтому `GET /catalog` их тоже отдаёт.

Каждый файл содержит `seededAt` и `source`. Файлы — источник для ревью,
`lib/src/seeds.g.dart` — рантайм-копия для устройства. После правки:

```sh
dart run tool/embed_seeds.dart
```

`test/seeds_test.dart` падает, если копии разошлись.

## Что воспроизводит mock

- роли (`guest`, `customer`, `support_agent`) с проверкой **на сервере**;
- `401` (битый/истёкший токен), `403` (чужая сущность, гость на checkout),
  `409 conflict_revision` (`If-Match`), `422 validation_failed`, `429 rate_limited`;
- корзина живёт 14 дней и пишет `cart.expire` в аудит;
- `Idempotency-Key` обязателен: тот же ключ + тело → тот же заказ, другое тело →
  `422 idempotency_conflict`;
- только forward-переходы статусов; неизвестный статус сериализуется как есть;
- один активный `PaymentIntent`; после оплаты новый → `409`;
- вебхуки подписаны HMAC-SHA256 (`X-Psp-Signature` + `X-Psp-Timestamp`, окно
  5 минут), без подписи → `401 invalid_signature`; дедупликация по
  `(provider, eventId)`, `succeeded` не откатывается;
- hosted page `/v1/mock/psp/hosted/{intentId}` — реальная HTML-страница без
  карточных полей; ссылка подписана токеном;
- возвраты full/partial, чек после оплаты;
- загрузки: JPEG/PNG ≤ 25 MiB, HEIC → `422 unsupported_format`, обрыв → `503`;
- `POST /orders/lookup`: одинаковая ошибка на неверный номер и телефон, лимит
  5 неудач на `IP + номер` за 15 минут с экспоненциальной блокировкой; карточка
  сокращённая (номер, статус, сумма, дата) — состав, адрес и код выдачи только
  владельцу;
- `POST /orders/{id}/claim`: только для гостевого заказа, лимит 3 попытки,
  чужой заказ → `409 order_already_claimed`, прежний гость сохраняет доступ;
- `login`: 5 неудач на email за 15 минут → `429`, успех сбрасывает счётчик;
- `verify`: 5 неверных кодов сжигают challenge → `410 challenge_expired`;
- загрузка: `PUT` проверяет размер, SHA-256 и magic bytes; `complete` без
  `PUT` → `409 upload_incomplete`;
- аудит: кто, когда, что, над каким объектом, результат; телефон маскируется
  (`***1234`), тела сообщений не пишутся;
- `DELETE /me`: каскад (сессии, черновики, корзины, заказы, платежи, загрузки,
  тикеты), аудит обезличивается (`deleted:<hash>`).

## Решения и известные ограничения

- **`spreadsCount` в `POST /price`**: для печати это число листов, для книг —
  число разворотов (цена книги зависит от разворотов, тираж — `quantity` в
  корзине).
- **Заказ без оплаты**: у `PaymentStatus` нет значения «не оплачен», поэтому
  заказ до оплаты отдаётся как `created`. Это задокументировано, а не выдумано
  новое значение.
- **Промокод в корзине**: в DTO `Cart` нет полей `discount`/`total`, поэтому
  скидка применяется к каждой строке, а `subtotal` — уже итог к оплате. Сумма
  строк всегда равна `subtotal`; это осознанный обход пробела контракта.
- **Preflight на checkout**: заказ с блокирующими замечаниями (пустой слот,
  неподдерживаемый формат) отклоняется `422 preflight_blocked`; пустой черновик
  — `422` с `empty_design`.
- **Секрет PSP**: `PSP_WEBHOOK_SECRET` из env/`--dart-define`; dev-фолбэк
  логируется и годится только для локального демо (ARCHITECTURE §8.10).
- **`/v1/mock/*`** — демо-контролы: регистрируются только при `MOCK_CONTROLS=1`
  (по умолчанию; `0` — прод-подобный прогон) и требуют `support_agent`
  (`MOCK_ALLOW_ANONYMOUS=1` — только для тестов). `advance` доступен support,
  клиенту — единственный переход `canceled`; `refunds` — только support.
- **Пароли в сидах**: PBKDF2-HMAC-SHA256, 100k итераций, формат
  `pbkdf2$<iterations>$<saltB64>$<hashB64>`.
- **Только 7 форматов** из 14 снимка (4 печати + 3 книги) — достаточно для
  сквозного сценария; расширяется правкой `catalog.json`.
