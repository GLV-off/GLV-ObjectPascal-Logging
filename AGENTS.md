# GLV Log — инструкции для агентов

Лёгкая библиотека логирования для Object Pascal (FPC/Lazarus + Delphi).
~1400 строк, 8 модулей, без зависимостей кроме FCL. Ветка `main`, релизов нет.

Два жёстких инварианта проекта (из `CONTRIBUTING.md`): код должен собираться
и в **FPC**, и в **Delphi**; API должен оставаться **максимально простым и легковесным**
(не тащить зависимости, не раздувать иерархию классов).

## Карта репозитория

```
lib/src/            исходники библиотеки (единственное место с логикой)
  glv_log_lib.inc     общий include компилятора: {$MODE DELPHI}{$H+} для FPC
  GlvLogTypes.pas     TLogLvl (llInfo, llDebug, llError, llWarn) + AsStr/LogLvlAsStr
  GlvLogBase.pas      абстрактный TLog — единственный метод Log(ALvl, ATxt)
  GlvLogCustom.pas    TCustomLog + TLogCb (callback of object)
  GlvLogGroup.pas     TGroupLog — fan-out, владеет детьми
  GlvLogFiles.pas     TPrimitiveFileLog (sync), TAsyncFileLog + TAsyncLogThread
  GlvLogFileOps.pas   внутренние IO-утилиты (CreateStream/WriteLines/WriteBom) — не публичный API
  GlvLogDev.pas       DevLog* — прямой WriteLn, API нестабилен, в фасад не входит
  GlvLog.pas          фасад: алиасы типов, TConsole, TLogging.Inst, Info/Warn/Error/Debug(+Fmt)
  backup/             старые версии юнитов, не в сборке — не трогать
lib/pkg/lz/         Lazarus-пакет glv_log_lib.lpk (+ автоген. glv_log_lib.pas — DO NOT EDIT)
lib/pkg/ct/         Code Typhon пакет (ctpkg, ctpkg.ctinfo), тот же автоген-юнит
test/src/           тесты: LogTestUnit (unit), LogTestInt (integration), TestEnv, TestFileUtils
test/pkg/lz/        Test.lpr (unit), TestInt.lpr (integration) + .lpi проекты
demos/simple/       демо: src/DemoApp.pas, pkg/{lz,ct,delphi}
doc/                unit_uses_tree_ru.md, undocumented_units_checklist_ru.md (RU)
lib/out, test/out, demos/simple/out   артефакты сборки — в git не входят, руками не править
```

Граф зависимостей: `GlvLogTypes ← GlvLogBase ← {Custom, Group, Files}; Files → FileOps (только в implementation); GlvLog (фасад) → всё вышеперечисленное, кроме Dev и FileOps`. При изменении зависимостей обновлять `doc/unit_uses_tree_ru.md`.

## Сборка и тесты

Готовых скриптов сборки нет — только Lazarus/CodeTyphon-проекты и `.lpk`.
FPC в PATH на текущей машине отсутствует (`which fpc` пуст), поэтому проверять
сборку можно лишь при установленном Lazarus/Typhon; если компилятора нет —
честно сообщить, что сборка не проверена, не выдумывать результат.

- Библиотека: открыть `lib/pkg/lz/glv_log_lib.lpk` → Compile/Install, либо добавить `lib/src` в unit search path.
- Демо: `demos/simple/pkg/lz/Demo.lpi` (Run), `.../ct/Demo.ctpr`, `.../delphi/Demo.dproj`.
- Тесты: `test/pkg/lz/Test.lpi` и `TestInt.lpi`. Оба требуют установленный пакет
  **`GlvTestCross`** из соседнего репозитория `../pas_TestingWrapper`
  (`Pkg/LZ/glvtestcross.lpk`) и пакет `glv_log_lib`. Без них тесты не соберутся.
- FPC напрямую (если include-файлы вне дерева юнита):
  `fpc -Mdelphi -Fulib/src -Filb/src -FUout/debug test/pkg/lz/Test.lpr`
- Выход: `out/<TargetCPU>-<TargetOS>/{Debug|Release|debug|release}`; имена каталогов
  BuildMode в `.lpi`/`.lpk` не унифицированы (Debug vs debug) — не «исправляй» без причины.
- Диффы держать чистыми: `out/`, `backup/`, `*.ppu`, `*.o`, `*.exe`, `*.log`, `*.lps` под `.gitignore`.
  В репозитории 39 отслеживаемых файлов; если появляются новые — проверить `.gitignore`.

## Соглашения кода

- Каждый юнит библиотеки начинается с `{$I 'glv_log_lib.inc'}` (даёт `{$MODE DELPHI}{$H+}` в FPC);
  тесты — с `{$I 'glv_log_test.inc'}`. Не заменять на инлайн-директивы.
- Шапка юнита — комментарий-блок: `Module: / Author: / Description: / History:`
  (`History: YYYY-MM-DD: Created`). Новые юниты оформлять так же.
- Имена: типы/классы `T...`, поля `F...`, параметры `A...`, приватные `strict private/protected`.
- `TLog` — `class abstract(TInterfacedObject)`; наследники переопределяют только
  `procedure Log(const ALvl: TLogLvl; const ATxt: string); override;`.
  Комментарии к публичным членам — в стиле `{ ... }` перед объявлением (уже так везде).
- Владедение: `TGroupLog` освобождает переданные ему логгеры; `TLogging.Inst` (сеттер)
  освобождает предыдущий экземпляр; остальные логгеры освобождает вызывающий (`FreeAndNil`).
  Не смешивать с подсчётом ссылок интерфейсов — объекты не передаются как интерфейсы.
- Один файл = один модуль; не добавлять `uses` в интерфейс без нужды (Facade намеренно
  тонкий). Файлы в CRLF, исходники в основном ASCII — сохранять переносы строк и кодировку.
- Пакетные юниты `lib/pkg/*/glv_log_lib.pas` автогенерируются IDE — не редактировать;
  новый юнит добавлять в `.lpk`/`.ctpkg` через IDE.

## Контракты, которые нельзя ломать (на них завязаны тесты)

| Логгер | Формат строки |
|---|---|
| `TPrimitiveFileLog` | `yyyy-mm-dd hh:nn:ss [LEVEL] text` (время через инъектируемый `TDateTimeFunc`, по умолчанию `Now`) |
| `TAsyncFileLog` | `[LEVEL]: text` |
| `TConsole.ConsoleLog` | `LEVEL: t.id=<ThreadID>, m=text` |
| `TLogLvl.AsStr` | `INFO/DEBUG/ERROR/WARN`, иначе `UNKNOWN` |

Файлы пишутся в UTF-8 (в `GlvLogFileOps` есть работа с BOM). Тесты сравнивают строки
посимвольно (`LogTestInt.pas`) — менять формат = править тесты в том же коммите.

## Известные дефекты и ловушки (WIP-проект)

Не «улучшать» молча: любое исправление — отдельным осмысленным изменением с тестом,
либо явно упомянуть в ответе, что осталось.

- `TAsyncLogThread.Execute`: нет ожидания (`Sleep`/event) → холостое вращение потока;
  условие `if FBuffer.Count >= 0` всегда истинно, поэтому файл перезаписывается на каждой итерации.
  Комментарий про «сброс каждые 8 записей» не соответствует коду.
- `GlvLogFileOps.WriteLines` пишет с `Position := 0` без усечения → при более коротком
  новом содержимом в конце файла остаётся «хвост» старых байт; после `WriteBom`
  безусловный `Position := 0` затирает BOM (заявленный в README BOM фактически не работает).
- `WriteBom` для непустого файла читает в `Buf`, а проверяет нулевой `Bom` → всегда `False`.
- `TAsyncLogThread.Destroy` сбрасывает только `FBuffer`, очередь `FQueue` теряется.
- `TPrimitiveFileLog` читает и перезаписывает файл целиком на каждое сообщение —
  не для больших логов; `UTF8Encode(FFilename)` при передаче в `FileExists/LoadFromFile`.
- `TCustomLog.Log` делает `UTF8Decode(ATxt)` перед `TLogCb` (`UnicodeString`):
  в FPC это осмысленно, в Delphi (`string` = `UnicodeString`) — потенциальное искажение.
- Фасад `GlvLog` экспортирует `TAsyncFileLogThread`, а README-пример использует
  `TAsyncLogThread` — пример требует `GlvLogFiles` в `uses`.
- `GlvLogDev`/`GlvLogFileOps` — внутренние, в фасад не входят; `TestFileOps` помечен `@deprecated`.
- `test/src/TestReport.pas` — пустая заготовка; `demos/simple/src/DemoApp.pas` и
  `pkg/delphi/Demo.dpr` ссылаются на отсутствующий `demo.inc` (незавершённая поддержка Delphi).
- `LogTestInt.TestAsyncLog` полагается на `Sleep(500)` и файловую систему — флаки при нагрузке.

## Как добавлять изменения

**Новый логгер**: юнит в `lib/src` с шапкой и `{$I}`, класс-наследник `TLog`, реализация
только `Log`; при необходимости — алиас в `GlvLog.pas` (иначе он недоступен пользователям
фасада); добавить юнит в `.lpk`/`.ctpkg` через IDE; тест в `test/src` (`TCrossTestCase`,
регистрация `CrossRegTest(TMyTest, 'Unit' | 'Int')` в `initialization`); обновить таблицы
в `README.md` и `doc/unit_uses_tree_ru.md`, чек-лист в `doc/undocumented_units_checklist_ru.md`.

**Новый уровень лога**: `GlvLogTypes.TLogLvl` + `LogLvlAsStr` + при необходимости обёртка
в `GlvLog.pas`; проверить `TLogLvlTest.TestAsStr`.

**Изменение формата вывода**: сначала правь ожидания в `LogTestInt.pas`, затем код;
формат продублирован в README-примерах.

Перед финалом: юнит компилируется в DELPHI-режиме, покрыт комментариями-блоками,
нет новых зависимостей кроме FCL, `git status` не содержит артефактов сборки,
тесты/сборка либо запущены, либо честно отмечено, что окружение недоступно.
