# AGV Token Tracker (Antigravity 2.0 Menu Bar Monitor) ⚡️

Нативний macOS додаток для статус-бару (Menu Bar), аналогічний до Syrtis / TokenBar, спеціально розроблений для відстеження використання токенів та витрат у **Antigravity 2.0**.

---

## 🚀 Можливості (Features)

- **Нативний macOS інтерфейс (SwiftUI & AppKit)**: Легкий, швидкий додаток для меню-бару з дизайном Liquid Glass (без іконки в Dock, працює виключно в статус-барі).
- **Підтримка Antigravity 2.0**: Автоматично знаходить та парсить транскрипти діалогів (`~/.gemini/antigravity/brain/**/transcript.jsonl`), включно з субагентами.
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
- **Live File Watcher**: Миттєве реактивне оновлення лічильників при генерації нових токенів у розмовах Antigravity без перезапуску.
- **Історія сесій**: Список останніх розмов із таймстемпами, моделями, кількістю кроків та вартістю.
- **Налаштування**: Вибір формату відображення в меню-барі (Токени, Вартість або тільки іконка), кастомний шлях до логів, ручна синхронізація цін.

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
├── AGVTokenTracker.swift          # Точка входу (@main) з MenuBarExtra (.window)
├── Models/
│   ├── TokenStep.swift            # Модель окремого кроку (PLANNER_RESPONSE)
│   ├── SessionSummary.swift       # Агрегована статистика сесії (UUID)
│   ├── TimePeriod.swift           # Логіка фільтрації за часом
│   └── ModelPricing.swift         # Розрахунок тарифів і вартості
├── Services/
│   ├── TranscriptScanner.swift    # Сканування та парсинг transcript.jsonl
│   ├── PricingService.swift       # Синхронізація з LiteLLM + офлайн-тарифи
│   └── FolderWatcher.swift        # FSEvents / DispatchSource спостерігач
├── ViewModels/
│   └── TrackerViewModel.swift     # Головна ViewModel стану додатку
└── Views/
    ├── StatusItemLabel.swift      # Відображення іконки та тексту в статус-барі
    ├── DashboardView.swift        # Головне поповер-вікно дашборду
    ├── HeroStatsCard.swift        # Картка загальних токенів та вартості
    ├── MetricCardView.swift       # 2x2 картки метрик (Input/Cache/Output/Eff)
    ├── SessionRowView.swift       # Елемент списку останніх розмов
    └── SettingsSheet.swift        # Вікно налаштувань
```

---

## 📄 Ліцензія

MIT License.
