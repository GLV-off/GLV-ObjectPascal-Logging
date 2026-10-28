# GLV Log - Pascal logging library

Lightweight logging library for Object Pascal (Free Pascal / Lazarus).
Minimal object-based API: assign log levels, write to console, to files
(synchronously or in a background thread) or to any custom sink via a callback.

## Features

- Object-oriented API based on a single abstract `TLog` with a `Log(InLvl, InTxt)` method
- Built-in log levels: `llInfo`, `llDebug`, `llError`, `llWarn`
- Loggers:
  - console output (`TCustomLog` + `TConsole`)
  - synchronous file logger (`TPrimitiveFileLog`)
  - asynchronous file logger with a dedicated background thread (`TAsyncFileLog` / `TAsyncLogThread`)
  - custom sink via method callback (`TCustomLog`)
- Group multiple loggers into one (`TGroupLog`) - fan-out to all children
- Fluent graph assembly (`TLogBuilder`) with an optional locking decorator (`TLockLog`)
- Hot-swappable active graph (`TLogHolder`) behind the stable V2 facade `GLV.Log`
- Ready-to-use singleton `TLogging.Inst` (console + async `log.log` by default, deprecated)
- UTF-8 (BOM) file output
- No dependencies beyond the Free Pascal FCL
- MIT license

## Requirements

- Free Pascal 3.x or newer (units require Delphi mode: `{$MODE DELPHI}`, `{$H+}`)
- Lazarus IDE (for building via the `.lpk` package and `.lpi` test projects)
- FCL (`SysUtils`, `Classes`, `Generics.Collections`, `SyncObjs`)

## Installation

Option 1 - via Lazarus package:

1. Open `lib/pkg/lz/glv_log_def_engine.lpk` with the Lazarus IDE
2. Compile/install the package or add it to your project's required packages

Option 2 - without an IDE: add `lib/src` to your project's unit search path
and compile with FPC directly.

## Quick Start

### V2: builder + holder (recommended)

The V2 API keeps client code on `GLV.Log` (`LogInfo` / `LogWarn` / `LogError` /
`LogDebug`) and hides `TLog` from it. The graph is assembled on startup with
`TLogBuilder` and installed into `TLogHolder`:

```pascal
uses
  GLV.Log,           { LogInfo/LogWarn/... }
  GLV.Log.Builder,   { TLogBuilder }
  GLV.Log.Holder;    { TLogHolder }

var
  B: TLogBuilder;
begin
  B := TLogBuilder.Create;
  try
    TLogHolder.Inst := B.Console.AsyncFile('app.log').WithLock().Build;
  finally
    B.Free;          { the builder only kept the sinks before Build }
  end;

  LogInfo('Application started');
end;
```

Notes:

- `TLogHolder.Inst` owns the graph; the builder is consumed by `Build` and may
  be freed right after it;
- the first assignment installs the engine callback and must happen before
  worker threads start;
- later assignments are a hot-swap: the replaced graph is not freed but kept
  until the holder is finalized, so a thread already inside it stays safe;
- `TLogHolder.Inst := nil` disables logging (`LogInfo` raises
  `ELoggingEngineNotInitialized`);
- do not mix the holder with `GLV.Log.ConsoleEngine` / `GLV.Log.SyncFileEngine`,
  which install their own callback in `initialization`.

### V1: single default logger (singleton, deprecated)

`TLogging` installs a group with console output and an async `log.log` file.
No initialization code needed. The class is deprecated: it frees the replaced
graph immediately and therefore cannot be hot-swapped from a worker thread.

```pascal
uses
  GlvLog;

begin
  TLogging.Inst.Log(llInfo, 'Application started');
  TLogging.Inst.Log(llError, 'Something went wrong');
end;
```

### Manual composition

Build your own logging pipeline from any combination of logger objects:

```pascal
uses
  GlvLog;

var
  L: TLog;
begin
  L := TGroupLog.Create([
    TCustomLog.Create(TConsole.ConsoleLog),        { console }
    TAsyncFileLog.Create(TAsyncLogThread.Create('app.log')) { async file }
  ]);
  try
    L.Log(llDebug, 'debug message');
    L.Log(llWarn, 'warning message');
  finally
    FreeAndNil(L);
  end;
end;
```

## Concepts

### Levels

`TLogLvl` supports `llInfo`, `llDebug`, `llError`, `llWarn`.
Use the helper `AsStr` or the standalone `LogLvlAsStr` to get an uppercase string:

```pascal
llInfo.AsStr   { returns 'INFO' }
LogLvlAsStr(llWarn) { returns 'WARN' }
```

### Logger classes

| Class | Description |
|---|---|
| `TLog` | Abstract base - the single logging interface (`Log(InLvl, InTxt)`) |
| `TCustomLog` | Redirects logging to a user-provided callback (`TLogCb`) |
| `TGroupLog` | Fan-out: forwards each message to all nested loggers |
| `TPrimitiveFileLog` | Simple sync file logger (rewrites the file on each message) |
| `TAsyncFileLog` | Async file logger backed by `TAsyncLogThread` |
| `TLockLog` | Serializes the wrapped logger with an outside lock (`TCriticalSection` by default) |
| `TLogBuilder` | Fluent assembly: console/sync/async/custom sinks, optional lock |
| `TLogHolder` | Holds the active graph for V2 and hot-swaps it safely |
| `TLogging` | Deprecated singleton; `Inst` returns a ready-to-use `TLog` group |

## Snippets

### Custom callback logger

Good for injecting your own logic (network sink, GUI list box, log rotation...):

```pascal
type
  TMyForm = class
  private
    procedure MyLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
  end;

procedure TMyForm.MyLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  Memo.Lines.Add(Format('%s: %s', [ALvl.AsStr, ATxt]));
end;

var
  L: TCustomLog;
begin
  L := TCustomLog.Create(Self.MyLog);
  L.Log(llDebug, 'custom log message');
end;
```

### File logger

Synchronous file logging with a timestamp prefix:

```pascal
var
  F: TPrimitiveFileLog;
begin
  F := TPrimitiveFileLog.Create('app.log');   { or Create(Filename, @DateTimeFunc) }
  F.Log(llInfo, 'saved');
end;
```

### Grouping multiple loggers

```pascal
var
  L: TLog;
begin
  L := TGroupLog.Create([
    TCustomLog.Create(TConsole.ConsoleLog),
    TAsyncFileLog.Create(TAsyncLogThread.Create('app.log')),
    TCustomLog.Create(TelegramBot.SendLog)
  ]);
end;
```

Note: `TGroupLog` owns the objects passed to it and frees them on destruction.
The same graph with `TLogBuilder` and an optional lock:

```pascal
var
  L: TLog;
  B: TLogBuilder;
begin
  B := TLogBuilder.Create;
  try
    L := B.Console
      .SyncFile('app.log')
      .Add(TCustomLog.Create(TelegramBot.SendLog))
      .WithLock()          { or .WithLock(MyCriticalSection) }
      .Build;
  finally
    B.Free;
  end;
  { L owns the whole graph (group + lock) }
end;
```

## Units overview

| Unit | Purpose |
|---|---|
| `GlvLog` | V1 facade - common types/classes, `TLogging` singleton (deprecated), V2 aliases |
| `GlvLogTypes` | `TLogLvl` and helpers (V1 copy) |
| `GlvLogBase` | Abstract `TLog` base class |
| `GlvLogCustom` | `TCustomLog`, `TLogCb` callback |
| `GlvLogGroup` | `TGroupLog` fan-out logger |
| `GlvLogFiles` | `TPrimitiveFileLog`, `TAsyncFileLog`, `TAsyncLogThread` |
| `GlvLogFileOps` | Internal IO utilities (not for public usage) |
| `GlvLogDev` | Developer-level routines `DevLog*` (not stable for public usage) |
| `GLV.Log` | V2 facade: `LogInfo` / `LogWarn` / `LogError` / `LogDebug` |
| `GLV.Log.Lvl` | V2 `TLogLvl` + `AsStr` / `LogLvlAsStr` |
| `GLV.Log.Engine` | V2 engine callback proxy (`TLogEngine`) |
| `GLV.Log.ConsoleEngine` | V2 console engine (installs its callback in `initialization`) |
| `GLV.Log.SyncFileEngine` | V2 sync file engine (uses V1 `TLogging`) |
| `GLV.Log.ConsoleSink` | `TConsole.ConsoleLog` - console sink for builder graphs |
| `GLV.Log.Lock` | `TLockLog` synchronization decorator |
| `GLV.Log.Builder` | `TLogBuilder` fluent graph assembly |
| `GLV.Log.Holder` | `TLogHolder` + `HolderLog` proxy for V2 |

## Known limitations

- `TLogging` is deprecated: use `TLogBuilder` + `TLogHolder` (V2).
- `TLogHolder` keeps replaced graphs until finalization (safe hot-swap costs
  memory for displaced graphs); there is no `Collect` yet.
- `TPrimitiveFileLog` reads the whole file into memory and rewrites it - not
  suitable for large/long-running logs; not thread-safe (comment in unit).
- Async file logger flushes to disk in batches (every 8 records queued).
- `GlvLogDev` is a developer tool - API is not stable.

## Demos

Two runnable projects show the library from different sides:

| Demo | Shows | Run |
|---|---|---|
| `demos/simple` | minimal V2 setup: `GLV.Log` + `GLV.Log.SyncFileEngine` | open `demos/simple/pkg/lz/Demo.lpi` in Lazarus and press Run |
| `demos/builder` | `TLogBuilder`: single sink, fan-out group, `TLockLog`, contract errors, `TLogHolder` hot-swap; async file is opt-in | open `demos/builder/pkg/lz/BuilderDemo.lpi` in Lazarus and press Run, or build it with `bash .pi/skills/pascal-build-probe/scripts/build.sh demo-builder` |

`BuilderDemo` accepts `--async` (also run the async file scenario),
`--wait` (wait for Enter) and `--help`. It writes `builder-sync.log` and
`builder-default.log` next to the executable. With `--async` it also attempts
to write `builder-async.log`; the async scenario only checks that the graph
can be built and stopped, because `TAsyncLogThread` has the known defects
listed below.

## Tests

Unit and integration testing uses wrapper library [](https://github.com/GLV-off/GLV_Pascal_TestingWrapper). You should clone this package before open autotesting project.

Build and run `test/pkg/lz/Test.lpr` (uses the `Glv.Testing` runner):

```sh
fpc -Mdelphi -FUtest/out/i386-win32/debug test/pkg/lz/Test.lpr
```

or open it in Lazarus and press Run. Test sources are in `test/src`.

## Documentation

- `doc/v1/unit_uses_tree_ru.md` - unit dependency tree (RU)
- `doc/v1/undocumented_units_checklist_ru.md` - documentation checklist (RU)
- `doc/v2/design_builder_ru.md` - V2 builder/holder design (RU)
- `doc/v2/usage.md` - V2 usage notes (RU)
- `CONTRIBUTING.md` - contribution guidelines

## License

[MIT](LICENSE)
