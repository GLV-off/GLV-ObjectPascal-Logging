# Дизайн: билдер лога и интеграция с V2

Статус: решения приняты, реализация не начата.
Дата: 2026-10-28.
Тулчейн найден `pascal-build-probe/scripts/probe.sh` (FPC 3.2.2 i386,
FPC 3.3.1 x64, lazbuild 5.99, `GlvTestCross` -- ok); сборка и тесты ещё
не запускались.

## 1. Цель и рамки

Собрать конфигурируемый лог из готовых реализаций `TLog` (консоль, синхронный
файл, асинхронный файл, произвольные sink'и) и подключить его к V2 через
стабильную процедуру-прокси, не открывая `TLog` клиентам V2.

Рамки:

- библиотека остаётся лёгкой: без DI-контейнеров, интерфейсных прослоек и
  новых внешних зависимостей (`CONTRIBUTING.md`);
- код должен собираться в FPC и Delphi;
- формат вывода существующих логгеров не меняется (контракты в `AGENTS.md`);
- V1-фасад (`GlvLog.*`) постепенно выводится из эксплуатации, но пока
  остаётся в сборке.

## 2. Принятые решения

| № | Решение |
|---|---|
| 1 | Вариант A: V2-only. Отдельный holder + стабильная процедура-прокси. Мост «V2 -> TLogging» не делаем, общий граф V1/V2 не поддерживаем |
| 2 | `GLV.Log.Holder` — вне контракта, в пакете `glv_log_def_engine` |
| 3 | Прокси регистрируется только в `SetInst`, без `initialization` |
| 4 | `GLV.Log.ConsoleEngine` / `GLV.Log.SyncFileEngine` не удаляем; документируем как взаимоисключающие с holder'ом |
| 5 | Hot-swap закладываем: retired-список, старые графы живут до финализации holder'а |
| 6 | V1-процедуры `Info/Warn/Error/Debug(+Fmt)` удаляем; `TLogging` помечаем `deprecated` |
| 7 | Мёртвые дубли `GlvLogConsole.pas`, `GlvLogEngine.pas`, `GlvLogContract.pas` удаляем сразу |
| 8 | Новые модули именуются `GLV.Log.*` (одно-два слова, не глубже) |

## 3. Нейминг

Правило: `GLV.Log.Слово.Слово`, не глубже, либо `GLV.Log.СловоСлово`.

| Модуль | Класс | Роль |
|---|---|---|
| `GLV.Log.Builder.pas` | `TLogBuilder` | fluent-сборка графа |
| `GLV.Log.Lock.pas` | `TLockLog` | декоратор синхронизации |
| `GLV.Log.ConsoleSink.pas` | `TConsole` | консольный sink (вынос из фасада) |
| `GLV.Log.Holder.pas` | `TLogHolder` | контейнер + прокси для V2 |

`GlvLog.*`, `GlvLogTypes`, `GlvLogBase` — существующие модули, правило к ним
не применяется.

## 4. Пакеты и слои (разведка)

Текущее состояние:

| Пакет | Содержимое | Зависимости |
|---|---|---|
| `glv_log_contract` | `GLV.Log.Engine`, `GLV.Log`, `GLV.Log.Lvl` (`lib/pkg/lz/glv_log_contract.lpk:26-39`) | только `FCL` (`:40-44`) |
| `glv_log_def_engine` | `GLV.Log.ConsoleEngine`, `GLV.Log.SyncFileEngine` (`lib/pkg/lz/glv_log_def_engine.lpk:22-31`) | `FCL` + `glv_log_contract` (`:32-39`), `OtherUnitFiles=..\..\src` (`:13`) |

`glv_log_def_engine` уже использует V1: `GLV.Log.SyncFileEngine.pas:11`
подключает `GlvLog`. Значит `glv_log_contract` — нижний слой, и добавлять в
`GLV.Log.Engine` зависимость от `GlvLogBase.TLog` нельзя: получится цикл
пакетов `contract -> GlvLogBase -> GLV.Log.Lvl -> contract`. `TLogEngine`
к тому же `sealed` (`GLV.Log.Engine.pas:38`).

Следствие: holder, builder, lock и console-sink живут в
`glv_log_def_engine`; контракт не меняется. Клиент, которому нужен только
`GLV.Log`, holder'а не увидит; для builder+holder ему нужен
`glv_log_def_engine` (а вместе с ним весь V1). Это неизбежно для варианта A.

CodeTyphon-пакет (`lib/pkg/ct/glv_log_def_engine.ctpkg:28-57`) сейчас не
содержит V2-юнитов; новые модули подтянут `GLV.Log.Lvl`/`GLV.Log.Engine`
из `lib/src` по search path так же, как уже подтягивается `GLV.Log.Lvl`
для `GlvLogBase`.

## 5. Публичные API

### 5.1. `GLV.Log.Lock` — `TLockLog`

Декоратор: владеет обёрнутым логгером, сериализует вызов `Log`.

```pascal
TLockLog = class(TLog)
strict private
  FInner: TLog;
  FSync: TSynchroObject;
  FOwnsSync: Boolean;
public
  { ASync = nil -> создаёт и владеет TCriticalSection.
    ASync <> nil -> заимствует, если AOwnsSync = False (по умолчанию). }
  constructor Create(const AInner: TLog;
    const ASync: TSynchroObject = nil;
    const AOwnsSync: Boolean = False);
  destructor Destroy; override;
  procedure Log(const InLvl: TLogLvl; const InTxt: UnicodeString); override;
end;
```

`Log`:

```pascal
FSync.Acquire;
try
  FInner.Log(InLvl, InTxt);
finally
  FSync.Release;
end;
```

Ограничения (в шапку юнита):

- допустимые примитивы — `TCriticalSection`, `TMutex`; `TEvent`/`TSimpleEvent`
  семантически не подходят;
- голый `TSynchroObject` может быть no-op `[гипотеза: проверить RTL]`;
- не вкладывать один и тот же лок в два `TLockLog`, не логировать рекурсивно
  из callback'а: реентерабельность зависит от RTL.

### 5.2. `GLV.Log.Builder` — `TLogBuilder`

```pascal
TLogBuilder = class
strict private
  FSinks: TObjectList<TLog>;
  FLock: TSynchroObject;
  FLockRequested: Boolean;
  procedure TakeSinks(out AItems: TArray<TLog>);
public
  constructor Create;
  destructor Destroy; override;

  function Add(const ASink: TLog): TLogBuilder;
  function Console: TLogBuilder;
  function SyncFile(const AFileName: UnicodeString): TLogBuilder; overload;
  function SyncFile(const AFileName: UnicodeString;
    const ADateTimeFunc: TDateTimeFunc): TLogBuilder; overload;
  function AsyncFile(const AFileName: UnicodeString): TLogBuilder;
  function WithLock(const ALock: TSynchroObject = nil): TLogBuilder;

  function Build: TLog;
end;
```

Семантика:

- порядок `Add*` = порядок вывода (`TGroupLog` итерирует по порядку);
- `Build` потребляет конфигурацию: sink'и передаются в граф, builder
  очищается и может использоваться повторно;
- 0 sink'ов -> `ELogBuilderError`; 1 sink -> он сам; N -> `TGroupLog`;
- `WithLock` оборачивает **весь** граф в `TLockLog` (лок снаружи);
- переданный в `WithLock` лок builder не освобождает (`TLockLog` заимствует);
- builder не потокобезопасен: конфигурировать на старте.

`Build`:

```pascal
if FSinks.Count = 0 then
  raise ELogBuilderError.Create('TLogBuilder: no sinks configured');
TakeSinks(Items);
if Length(Items) = 1 then
  Result := Items[0]
else
  Result := TGroupLog.Create(Items);
if FLockRequested then
  Result := TLockLog.Create(Result, FLock);
```

`TakeSinks`:

```pascal
AItems := FSinks.ToArray;
FSinks.OwnsObjects := False;
FSinks.Clear;
FSinks.OwnsObjects := True;
```

`Console` создаёт `TCustomLog.Create(TConsole.ConsoleLog)`, где `TConsole`
берётся из `GLV.Log.ConsoleSink`.

### 5.3. `GLV.Log.Holder` — `TLogHolder`

```pascal
TLogHolder = class sealed
strict private class var
  FInst: TLog;
  FRetired: TObjectList<TLog>;
  FLock: TCriticalSection;
  FRegistered: Boolean;
  class function GetInst: TLog; static;
  class procedure SetInst(const AValue: TLog); static;
public
  class constructor Create;
  class destructor Destroy;
  class property Inst: TLog read GetInst write SetInst;
end;

procedure HolderLog(const InLvl: TLogLvl; const InTxt: UnicodeString);
```

`SetInst`:

```pascal
FLock.Acquire;
try
  if AValue = FInst then
    Exit;
  if not FRegistered then
  begin
    TLogEngine.SetCb(@HolderLog);
    FRegistered := True;
  end;
  if Assigned(FInst) then
    FRetired.Add(FInst);
  FInst := AValue;
finally
  FLock.Release;
end;
```

`HolderLog`:

```pascal
L := TLogHolder.Inst;
if not Assigned(L) then
  raise ELoggingEngineNotInitialized.Create(
    'GLV.Log.Holder: TLogHolder.Inst is not configured');
L.Log(InLvl, InTxt);
```

`Destroy`: освободить `FInst`, затем `FRetired`, затем `FLock`.

Свойства:

- callback в `TLogEngine` стабилен: при подмене графа `SetCb` повторно
  не вызывается (только при первой установке);
- первая установка — до старта рабочих потоков (иначе гонка на рекорде
  `TLogEngineCallback`, см. п. 8);
- последующие подмены безопасны: старый граф уходит в `FRetired` и живёт
  до финализации holder'а;
- `Inst := nil` отключает логирование: прокси бросает
  `ELoggingEngineNotInitialized`;
- не смешивать с `GLV.Log.ConsoleEngine`/`GLV.Log.SyncFileEngine`, которые
  ставят callback в `initialization`.

### 5.4. Фасад `GlvLog.pas`

- удалить `Info`, `Warn`, `Error`, `Debug`, `InfoFmt`, `WarnFmt`, `ErrorFmt`,
  `DebugFmt` (fan-in 0; контрактный Unicode-трап `Format` уходит вместе с ними);
- `TConsole` -> алиас `GLV.Log.ConsoleSink.TConsole`;
- добавить алиасы `TLockLog`, `TLogBuilder`;
- `TLogging` пометить `deprecated` (шум в `GLV.Log.SyncFileEngine` и README —
  ожидаемо). Синтаксис директивы проверить в FPC и Delphi;
- `TLogging` не удалять, пока на нём висит `GLV.Log.SyncFileEngine`
  (`:15,20`). Триггер удаления: holder в демо + `SyncFileEngine` больше
  не использует `TLogging`.

## 6. Владение

| Что | Кто освобождает |
|---|---|
| sink'и до `Build` | builder (если `Build` не вызывался) |
| sink'и после `Build` | `TGroupLog` (N > 1) либо вызывающий (N = 1) |
| inner у `TLockLog` | `TLockLog` |
| лок, созданный `TLockLog` (передан `nil`) | `TLockLog` |
| лок, переданный в `WithLock`/`Create` | вызывающий (`AOwnsSync=False`) |
| `FInst` и `FRetired` | `TLogHolder` |
| граф, отданный в `TLogging.Inst` | `TLogging` (не смешивать с holder'ом) |

`TLog = class abstract(TInterfacedObject)` (`GlvLogBase.pas:23`): не передавать
эти объекты как интерфейсы, иначе подсчёт ссылок + `FreeAndNil` дадут
double free.

## 7. Hot-swap и retired

Проблема: поток T1 уже внутри `OldGraph.Log(...)`, когда приходит
`Inst := NewGraph`. Немедленный `OldGraph.Free` — use-after-free.

Решение: `SetInst` не освобождает старый граф, а перекладывает его в
`FRetired`; `HolderLog` вызывает `L.Log` без удержания лока holder'а.
Старый объект жив до финализации holder'а. Плата — память под вытесненные
графы; для «настроили на старте, изредка перечитали конфиг» это единицы
объектов.

`Collect` в API не добавляем (exit-only). Если появится сценарий
«долгоживущий сервис + много переконфигураций», добавить
`TLogHolder.Collect` с явным требованием «только в точке покоя» (остановить
рабочие потоки), а не автоматически.

Альтернатива (не выбрана): coarse lock на весь `L.Log` — освобождение сразу,
но сериализация всех сообщений и избыточность с `TLockLog`.

Вытесненный `TAsyncFileLog` не теряет очередь: поток дописывает буфер и
засыпает; при финализации holder'а `Destroy` делает `Terminate/WaitFor/Free`
(`GlvLogFiles.pas:221-229`).

## 8. Гонка первого `SetCb` (разведка, паркуем)

`TLogEngineCallback` — рекорд с вариантным полем (`GLV.Log.Engine.pas:32-35`):
`Kind` + `Meth` (2 указателя) / `Proc` (1 указатель). `SetCb` присваивает
весь рекорд (`:106-113`), `Call` читает `Kind`, затем payload (`:68-83`).
Присваивание рекорда не атомарно. Сценарий: `Call` прочитал
`Kind = leckProc`, затем `SetCb` записал `Kind = leckMeth` и новые
`Meth.Code/Data`; `Call` вызывает метод как обычную процедуру — UB.

Риск актуален только на **первой** установке holder'а. Дальше
`FRegistered = True`, `SetCb` не вызывается; hot-swap меняет только указатель
в holder'е. Все существующие `SetCb` — в `initialization` движков, до старта
программы.

Правило: первый `Inst :=` — до запуска рабочих потоков. Hardening
`TLogEngine` (immutable-рекорд + атомарная подмена, либо лок) **паркуем**
с триггером: «runtime-перерегистрация callback станет официальным сценарием».

## 9. Удаление мёртвых дублей

Удалить сразу:

- `lib/src/GlvLogConsole.pas` — дубль `GLV.Log.ConsoleEngine.pas` (отличается
  только unit/uses);
- `lib/src/GlvLogEngine.pas` — старый дубль `GLV.Log.Engine.pas`;
- `lib/src/GlvLogContract.pas` — старый дубль `GLV.Log.pas`.

Ссылок нет ни в пакетах, ни в тестах/демо (проверено grep).

## 10. Тесты

Тесты — в `test/src`, регистрация `CrossRegTest(..., 'Unit' | 'Int')`,
проекты `Test.lpi`/`TestInt.lpi` уже требуют `glv_log_def_engine`.

`TLockLog`:

1. spy-наследник `TSynchroObject` считает `Acquire`/`Release`;
2. `Release` вызывается при исключении в callback'е;
3. `Acquire` до входа в callback, `Release` после;
4. владение: свой CS освобождается; переданный (borrowed) — нет.

`TLogBuilder`:

1. 0 sink'ов -> `ELogBuilderError`;
2. 1 sink -> он сам; 2 -> `TGroupLog`;
3. порядок вывода = порядок `Add`;
4. `Build` передаёт владение, деструктор builder'а граф не освобождает;
5. повторный `Build` даёт новый граф;
6. `WithLock` оборачивает весь граф (spy-лок видит одно Acquire на сообщение).

`TLogHolder`:

1. `Inst := spy` -> `GLV.Log.LogInfo` доходит с `llInfo` и тем же
   `UnicodeString` (включая не-ASCII);
2. переприсваивание не освобождает старый граф; он освобождается при
   финализации holder'а;
3. `Inst := nil` -> `LogInfo` бросает `ELoggingEngineNotInitialized`;
4. hot-swap: поток логирует, главный поток делает `Inst := new` — без AV,
   сообщения уходят в старый или новый sink;
5. `TearDown` — `Inst := nil` (изоляция).

Интеграционно (sync): формат `yyyy-mm-dd hh:nn:ss [LEVEL] text` не изменился;
переиспользовать ожидания `LogTestInt.pas:73-85`. Async-тест не добавлять
без устранения `Sleep(500)`-флаки.

## 11. Пакеты и сборка

Новые юниты добавлять скриптом `pascal-package-sync`
(`.pi/skills/pascal-package-sync/scripts/pkg-add-unit.sh <pkg> <unit> --check`,
затем без `--check`):

- `lib/pkg/lz/glv_log_def_engine.lpk`;
- `lib/pkg/ct/glv_log_def_engine.ctpkg`.

Автогенерируемые `lib/pkg/*/glv_log_def_engine.pas` руками не править —
их пересобирает IDE после правки `.lpk`/`.ctpkg`.
Проверка: `pkg-inventory.sh` (юнит в `UNITPKG`, `COVER` вырос) и
`pascal-build-probe/scripts/build.sh` (`lib-v2`, `lib-v1-ct`, `tests`,
`tests-int`). Провал сборки — вход в бэклог, а не повод править «на глаз».

## 12. Порядок работ

1. Cleanup: удалить 3 мёртвых юнита, проверить ссылки.
2. `GLV.Log.ConsoleSink`: вынести `TConsole`, фасад — алиас.
3. V1 API: удалить 8 процедур, обновить `AGENTS.md:22`, `TLogging` -> deprecated.
4. `GLV.Log.Lock`: `TLockLog` + тесты.
5. `GLV.Log.Builder`: `TLogBuilder` + тесты.
6. `GLV.Log.Holder`: `TLogHolder` + hot-swap тесты.
7. Доки: README, `doc/v2/usage.md`, `doc/v1/unit_uses_tree_ru.md`,
   `doc/undocumented_units_checklist_ru.md`; при желании — демо на Builder+Holder.

## 13. Сознательно не делаем

- `TLogHolder.Collect` и автоматическую сборку retired;
- hardening `TLogEngine` (атомарная подмена callback);
- общий граф V1<->V2 через `TLogging`;
- DI-контейнер, интерфейсы поверх `TLog`, фабрики/регистраторы;
- фильтрацию по уровню, ротацию, форматтеры;
- удаление `TLogging` и `*Engine`-стабов в этом заходе.

## 14. Известные дефекты, которые билдер не исправляет

Из `AGENTS.md`:

- `TAsyncLogThread.Execute`: холостое вращение, `if FBuffer.Count >= 0`,
  потеря `FQueue` в `Destroy`;
- `GlvLogFileOps.WriteLines`: запись с `Position := 0` без усечения,
  неработающий BOM;
- `TPrimitiveFileLog`: чтение/перезапись файла на каждое сообщение,
  `UTF8Encode(FFilename)` как путь;
- `Format` и Unicode в `*Fmt` — уходят вместе с V1-процедурами.

## 15. Открытые вопросы

1. Пакетные правки — скриптом `pascal-package-sync` (IDE не нужен для XML,
   но автоген-юнит пересобирает IDE/пакетный менеджер).
2. Проверить синтаксис `deprecated` для класса в FPC и Delphi.
3. Прогнать сборку/тесты через `pascal-build-probe` и зафиксировать результат.
