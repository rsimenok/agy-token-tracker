# AGV Token Tracker (Antigravity Unified Menu Bar Monitor) ⚡️

Нативний macOS додаток для статус-бару (Menu Bar), аналогічний до Syrtis / TokenBar, спеціально розроблений для моніторингу використання токенів та витрат в усій екосистемі **Antigravity**:
1. **Antigravity 2.0 (Desktop)**
2. **Antigravity CLI (`agy`)**
3. **Antigravity IDE (VS Code Extension / LS)**

---

## 🚀 Можливості (Features)

- **Нативний macOS інтерфейс (SwiftUI & AppKit)**: Легкий, швидкий додаток для меню-бару з дизайном Liquid Glass (без іконки в Dock, працює виключно в статус-барі).
- **Мульти-додатковий трекінг (Unified & Filterable)**:
  - 🌐 **All (Unified)**: Загальний підсумок по всій екосистемі з інтерактивними картками розбивки по кожному додатку.
  - 🖥️ **2.0 (Desktop)**: Відстеження окремо для десктопного Antigravity 2.0 (`~/.gemini/antigravity/brain/**/transcript.jsonl`).
  - 💻 **CLI (`agy`)**: Відстеження консольних сесій CLI (`~/.gemini/antigravity-cli`).
  - 📝 **IDE**: Відстеження IDE розширень (`~/.gemini/antigravity-ide/conversations/*.db`).
- **Гнучкі часові періоди**:
  - **Сьогодні (Today)**
  - **Вчора (Yesterday)**
  - **Цього тижня (This Week)**
  - **Цього місяця (This Month)**
  - **За весь час (All Time)**
- **Детальна розбивка токенів**:
  - 📥 **Input Tokens**: свіжий контекст та запити користувача.
  - ⚡️ **Cache Read Tokens**: кешований контекст (Context Caching) з відображенням економії (~75%).
  - 📤 **Output Tokens**: згенерований текст та reasoning/thinking токени.
  - 🎯 **Cache Efficiency**: коефіцієнт попадання в кеш (Cache Hit Ratio %).
- **Розрахунок вартості ($ USD)**:
  - Автоматичне завантаження актуальних тарифів з відкритої бази **LiteLLM** (`model_prices_and_context_window.json`).
  - Вбудована офлайн-таблиця для сімейства **Gemini 3.8/2.5/2.0/1.5 Flash**, **Gemini Pro** та **Claude**.
- **Двошаровий парсер (JSONL + SQLite Protobuf)**:
  - Потоковий JSONL аналізатор для швидкого читання траєкторій планувальника.
  - Вбудований нативний SQLite та легковий декодер wire-формату Google Protobuf (`gen_metadata`) без зовнішніх C++ бібліотек.
- **Live File Watcher**: Миттєве реактивне оновлення лічильників при генерації нових токенів у розмовах Desktop, CLI або IDE.
- **Історія сесій**: Список останніх розмов із кольоровими бейджами додатку (`[2.0]`, `[CLI]`, `[IDE]`), таймстемпами, моделями, кількістю кроків та вартістю.
- **Налаштування**: Статус моніторингу шляхів усіх трьох середовищ, швидкий перехід у Finder, вибір формату в меню-барі (Токени, Вартість або тільки іконка), ручна синхронізація тарифів.

---

## 🛠 Збірка та запуск (Build & Run)

### Системні вимоги:
- macOS 14.0 (Sonoma) або новіша (Apple Silicon & Intel).
- Xcode 16+ або встановлені Command Line Tools (`swift`).

### 1. Швидкий запуск у режимі розробки:
```bash
swift run
```

### 2. Запуск тестів:
```bash
swift test
```

### 3. Створення готового macOS `.app` бандла:
```bash
./scripts/build_app.sh
```
Після виконання скрипта готовий додаток буде збережено в `build/AGVTokenTracker.app`. Ви можете запустити його:
```bash
open build/AGVTokenTracker.app
```
або скопіювати у папку програм:
```bash
cp -r build/AGVTokenTracker.app /Applications/
```

---

## 📂 Архітектура проекту

```text
Sources/AGVTokenTracker/
├── AGVTokenTracker.swift              # Точка входу (@main) з MenuBarExtra (.window)
├── Models/
│   ├── AppSurface.swift               # Перелік поверхонь (.all, .desktop, .cli, .ide)
│   ├── TokenStep.swift                # Модель окремого кроку та SessionSummary
│   ├── TimePeriod.swift               # Логіка фільтрації за часом
│   └── ModelPricing.swift             # Розрахунок тарифів і вартості
├── Services/
│   ├── UnifiedScanner.swift           # Головний координатор збору даних з усіх середовищ
│   ├── TranscriptScanner.swift        # Сканування та парсинг transcript.jsonl
│   ├── SQLiteConversationScanner.swift# SQLite + Protobuf парсер для CLI та IDE баз даних
│   ├── PricingService.swift           # Синхронізація з LiteLLM + офлайн-тарифи
│   └── FolderWatcher.swift            # FSEvents / DispatchSource мульти-директорійний спостерігач
├── ViewModels/
│   └── TrackerViewModel.swift         # Головна ViewModel стану додатку
└── Views/
    ├── StatusItemLabel.swift          # Відображення іконки та тексту в статус-барі
    ├── DashboardView.swift            # Головне поповер-вікно дашборду з розбивкою по додатках
    ├── HeroStatsCard.swift            # Картка загальних токенів та вартості
    ├── MetricCardView.swift           # 2x2 картки метрик (Input/Cache/Output/Eff)
    ├── SessionRowView.swift           # Елемент списку розмов із бейджами поверхонь
    └── SettingsSheet.swift            # Вікно налаштувань та перегляду статусів директорій
```

---

## 📄 Ліцензія

MIT License.
