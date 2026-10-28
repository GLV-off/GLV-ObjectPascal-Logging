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
  GlvLogBase.pas      абстрактный TLog — единственный метод Log(InLvl, InTxt: UnicodeString)
  GlvLogCustom.pas    TCustomLog + TLogCb (callback of object)
  GlvLogGroup.pas     TGroupLog — fan-out, владеет детьми
  GlvLogFiles.pas     TPrimitiveFileLog (sync), TAsyncFileLog + TAsyncLogThread
  GlvLogFileOps.pas   внутренние IO-утилиты (CreateStream/WriteLines/WriteBom) — не публичный API
  GlvLogDev.pas       DevLog* — прямой WriteLn, API нестабилен, в фасад не входит
  GlvLog.pas          фасад V1: алиасы типов, TLogging.Inst (deprecated), алиасы V2-типов
  GLV.Log.Lvl.pas     V2-контракт: TLogLvl + AsStr/LogLvlAsStr
  GLV.Log.Engine.pas  V2-контракт: TLogEngine — стабильный callback-прокси
  GLV.Log.pas         V2: LogInfo/LogError/LogWarn/LogDebug поверх TLogEngine
  GLV.Log.ConsoleSink.pas  TConsole.ConsoleLog — консольный sink (алиас в фасаде)
  GLV.Log.Lock.pas    TLockLog — декоратор синхронизации, владеет inner-логгером
  GLV.Log.Builder.pas TLogBuilder — fluent-сборка графа (вне контракта)
  GLV.Log.Holder.pas  TLogHolder + HolderLog — хот-свап активного графа для V2
  backup/             старые версии юнитов, не в сборке — не трогать
lib/pkg/lz/         Lazarus-пакеты: glv_log_def_engine.lpk (GlvLog*, GLV.Log.*Engine,
                    GLV.Log.ConsoleSink/Lock/Builder/Holder)
                    и glv_log_contract.lpk (GLV.Log, GLV.Log.Lvl, GLV.Log.Engine)
                    (+ автоген. одноимённые *.pas — DO NOT EDIT)
lib/pkg/ct/         Code Typhon пакет glv_log_def_engine (ctpkg, ctinfo.txt, тот же автоген-юнит;
                    V2-юниты подтягивают GLV.Log.Lvl/Engine из lib/src по search path)
test/src/           тесты: LogTestUnit (unit), LogTestInt (integration), TestEnv, TestFileUtils
test/pkg/lz/        Test.lpr (unit), TestInt.lpr (integration) + .lpi проекты
demos/simple/       демо движка V2: src/DemoApp.pas, pkg/{lz,ct,delphi}
demos/builder/      демо Builder+Holder: src/BuilderDemoApp.pas, pkg/lz
doc/v1/             unit_uses_tree_ru.md, undocumented_units_checklist_ru.md (RU)
doc/v2/             design_builder_ru.md (принятый дизайн), usage.md, req_engine.md (RU)
lib/out, test/out, demos/simple/out, demos/builder/out   артефакты сборки — в git не входят, руками не править
```

Граф зависимостей: `GLV.Log.Lvl ← GlvLogBase ← {Custom, Group, Files, ConsoleSink, Lock, Holder}`;
`GLV.Log.Builder → {ConsoleSink, Lock, Custom, Group, Files}`; `GLV.Log.Holder → GLV.Log.Engine`;
`Files → FileOps` (только в implementation); `GlvLog` (фасад) → `{Lvl, ConsoleSink, Lock, Builder}`
и весь V1, кроме Dev и FileOps. При изменении зависимостей обновлять `doc/v1/unit_uses_tree_ru.md`.

## Сборка и тесты

Готовых скриптов сборки нет — только Lazarus/CodeTyphon-проекты и `.lpk`.
FPC в PATH на текущей машине отсутствует (`which fpc` пуст), поэтому проверять
сборку можно лишь при установленном Lazarus/Typhon; если компилятора нет —
честно сообщить, что сборка не проверена, не выдумывать результат.

- Библиотека: открыть `lib/pkg/lz/glv_log_def_engine.lpk` (v1) или `lib/pkg/lz/glv_log_contract.lpk` (v2) → Compile/Install, либо добавить `lib/src` в unit search path.
- Демо: `demos/simple/pkg/lz/Demo.lpi` (Run), `.../ct/Demo.ctpr`, `.../delphi/Demo.dproj`;
  `demos/builder/pkg/lz/BuilderDemo.lpi` (Run).
- Тесты: `test/pkg/lz/Test.lpi` и `TestInt.lpi`. Оба требуют установленный пакет
  **`GlvTestCross`** из соседнего репозитория `../pas_TestingWrapper`
  (`Pkg/LZ/glvtestcross.lpk`) и пакет `glv_log_def_engine` (TestInt.lpi) либо `glv_log_contract` (Test.lpi). Без них тесты не соберутся.
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
- Имена: типы/классы `T...`, поля `F...`, параметры `A...` (входные параметры API — `In...`,
  как в `GLV.Log.*` и `TLog.Log`), приватные `strict private/protected`.
- `TLog` — `class abstract(TInterfacedObject)`; наследники переопределяют только
  `procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;`
  (текст — `UnicodeString`, кодированием в байты занимается конкретный логгер).
  Комментарии к публичным членам — в стиле `{ ... }` перед объявлением (уже так везде).
- Владедение: `TGroupLog` освобождает переданные ему логгеры; `TLogging.Inst` (сеттер)
  освобождает предыдущий экземпляр; `TLogBuilder` владеет sink'ами до `Build` (после —
  граф/вызывающий), `TLockLog` владеет inner и созданным им локом, но не заимствованным;
  `TLogHolder` владеет активным и вытесненными графами до финализации; остальные логгеры
  освобождает вызывающий (`FreeAndNil`).
  Не смешивать с подсчётом ссылок интерфейсов — объекты не передаются как интерфейсы.
- Один файл = один модуль; не добавлять `uses` в интерфейс без нужды (Facade намеренно
  тонкий). Файлы в CRLF, исходники в основном ASCII — сохранять переносы строк и кодировку.
- Пакетные юниты `lib/pkg/lz/*.pas` и `lib/pkg/ct/*.pas` автогенерируются IDE — не редактировать;
  новый юнит добавлять в `.lpk`/`.ctpkg` через IDE.

## Контракты, которые нельзя ломать (на них завязаны тесты)

| Логгер | Формат строки |
|---|---|
| `TPrimitiveFileLog` | `yyyy-mm-dd hh:nn:ss [LEVEL] text` (время через инъектируемый `TDateTimeFunc`, по умолчанию `Now`) |
| `TAsyncFileLog` | `[LEVEL]: text` |
| `TConsole.ConsoleLog` | `LEVEL: t.id=<ThreadID>, m=text` (`GLV.Log.ConsoleSink`, алиас в фасаде) |
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
- Кодировки: `TLog.Log`/`TLogCb` — `UnicodeString`; файловые логгеры сами кодируют в UTF-8
  (`UTF8Encode` + `RawByteString` в `TPrimitiveFileLog` и `GlvLogFileOps.WriteLines`).
  Остаётся ловушка `Format`: в FPC он работает через `AnsiString`, поэтому
  `Format('%s', [UnicodeString])` теряет не-ASCII (`???`) на не-UTF-8 системной
  кодировке. V1-процедуры `Info/Warn/Error/Debug(+Fmt)` удалены вместе с этим
  контрактом; в V2 `GLV.Log.LogInfo` идёт в `TLog.Log` напрямую, но любой `Format`
  внутри логгера или callback'а Unicode-safe не гарантирован.
- Фасад `GlvLog` экспортирует `TAsyncFileLogThread`, а README-пример использует
  `TAsyncLogThread` — пример требует `GlvLogFiles` в `uses`.
- `GlvLogDev`/`GlvLogFileOps` — внутренние, в фасад не входят; `TestFileOps` помечен `@deprecated`.
- `test/src/TestReport.pas` — пустая заготовка; `demos/simple/src/DemoApp.pas` и
  `pkg/delphi/Demo.dpr` ссылаются на отсутствующий `demo.inc` (незавершённая поддержка Delphi).
  `demos/builder` не использует `demo.inc`; его сборка в Delphi не проверялась (`dcc` нет).
- `LogTestInt.TestAsyncLog` полагается на `Sleep(500)` и файловую систему — флаки при нагрузке.

## Как добавлять изменения

**Новый логгер**: юнит в `lib/src` с шапкой и `{$I}`, класс-наследник `TLog`, реализация
только `Log`; при необходимости — алиас в `GlvLog.pas` (иначе он недоступен пользователям
фасада); добавить юнит в `.lpk`/`.ctpkg` через IDE; тест в `test/src` (`TCrossTestCase`,
регистрация `CrossRegTest(TMyTest, 'Unit' | 'Int')` в `initialization`); обновить таблицы
в `README.md` и `doc/v1/unit_uses_tree_ru.md`, чек-лист в `doc/v1/undocumented_units_checklist_ru.md`.

**V1 vs V2**: новый код — только `GLV.Log.*` (builder/holder); фасад `GlvLog` —
legacy-слой, новые алиасы туда добавлять только по необходимости.
Не смешивать `TLogging` и `TLogHolder`: оба ставят глобальный активный граф.
`GLV.Log.ConsoleEngine`/`GLV.Log.SyncFileEngine` взаимоисключающи с holder'ом
(они ставят callback в `initialization`).

**Новый уровень лога**: `GlvLogTypes.TLogLvl` + `LogLvlAsStr` + при необходимости обёртка
в `GlvLog.pas`; проверить `TLogLvlTest.TestAsStr`.

**Изменение формата вывода**: сначала правь ожидания в `LogTestInt.pas`, затем код;
формат продублирован в README-примерах.

Перед финалом: юнит компилируется в DELPHI-режиме, покрыт комментариями-блоками,
нет новых зависимостей кроме FCL, `git status` не содержит артефактов сборки,
тесты/сборка либо запущены, либо честно отмечено, что окружение недоступно.
