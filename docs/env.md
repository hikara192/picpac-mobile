# Конфигурация окружения

Параметры приложения передаются через `--dart-define`. Секретов здесь нет и быть
не может. Переменные AI-провайдера (`AGENT_*`) читает **процесс mock/BFF**, а не
сборка приложения: см. раздел ниже и `.env.example`.

| Параметр | Значения | По умолчанию | Смысл |
|---|---|---|---|
| `API_MODE` | `embedded` \| `http` | `embedded` | `embedded` поднимает mock API внутри приложения на loopback; `http` идёт на внешний адрес |
| `API_BASE_URL` | абсолютный URL | — | Обязателен при `API_MODE=http`. Без `/v1` — префикс добавляется клиентом |
| `APP_ENV` | `dev` \| `staging` \| `prod` | `dev` | Влияет на аналитику (prod отключает debug-лог) и запрет HTTP вне dev |
| `AI_ENABLED` | `true` \| `false` | `false` | AI-контур выключен на этапе 0 (ADR-006) |

### AI-провайдер за BFF (только сервер `mock_server`, не сборка приложения)

Ключи и адреса провайдера — это **окружение процесса BFF**, а не `--dart-define`.
Приложение к шлюзу не обращается: оно говорит только с `POST /v1/ai/patch`.
Имена переменных перечислены в `.env.example`, значений в репозитории нет.

| Параметр | Значения | По умолчанию | Смысл |
|---|---|---|---|
| `AI_PROVIDER` | `mock` \| `none` \| `agent` (`opencode`, `opencode-go`, `pi`, `pi-agent` — алиасы `agent`) | `mock` | `mock` — правила `DesignAdvisor`; `none` — `503 ai_disabled`; `agent` — OpenAI-совместимый шлюз |
| `AGENT_BASE_URL` | абсолютный URL без `/chat/completions`, например `http://127.0.0.1:8080/v1` | — | Обязателен при `AI_PROVIDER=agent`; пусто → `503 ai_not_configured` (сервер не падает на старте) |
| `AGENT_MODEL` | alias модели в шлюзе | — | Уходит в `model` запроса и в `meta.model`; не секрет |
| `AGENT_API_KEY` | токен шлюза | — | Только из secret manager / env процесса; не логируется, не отдаётся клиенту |

## Примеры

iOS-симулятор + встроенный mock (ничего не нужно поднимать):
```sh
./scripts/run.sh ios      # найдёт симулятор по targetPlatform, id — UUID
# эквивалент вручную:
flutter run -d "iPhone 18 Pro"
```

iOS-симулятор + отдельный mock:
```sh
PORT=9090 ./scripts/dev.sh ios   # поднимет mock и передаст API_MODE/API_BASE_URL
# эквивалент вручную:
./scripts/dev-api.sh &
flutter run -d "iPhone 18 Pro" \
  --dart-define=API_MODE=http \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Android-эмулятор + отдельный mock (хост виден как `10.0.2.2`):
```sh
./scripts/dev.sh android
```

Реальное устройство:
```sh
flutter run -d <device-id> \
  --dart-define=API_MODE=http \
  --dart-define=API_BASE_URL=https://<debug-host>
```

Набор через файл:
```sh
flutter run --dart-define-from-file=env.json   # не коммитить секреты
```

## Платформенные ограничения

- iOS: `NSAllowsLocalNetworking` включён, `NSAllowsArbitraryLoads` — нет. Release-сборка говорит только по HTTPS.
- Android: `usesCleartextTraffic="false"` в release; cleartext разрешён только для `127.0.0.1`, `10.0.2.2`, `localhost` в **debug**-варианте (`android/app/src/debug/res/xml/network_security_config.xml`).
- Токены — только Keychain/Keystore (`flutter_secure_storage`), не в `SharedPreferences`.
